import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sig_app/planning_semaine_personnel.dart';
import 'package:sig_app/profile_page.dart';
import 'package:sig_app/rapport_admin.dart';
import 'package:sig_app/rapport_controller.dart';
import 'package:sig_app/taches_controleur.dart';

import 'consulter_entreprise.dart';
import 'creer_planning_page.dart';
import 'localisation_page.dart';
import 'message_page.dart';

class ControllerDashboard extends StatefulWidget {
  const ControllerDashboard({super.key});

  @override
  _ControllerDashboardState createState() => _ControllerDashboardState();
}

class _ControllerDashboardState extends State<ControllerDashboard> {
  int _selectedIndex = 0;
  bool _sidebarExtended = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, bool> _userPermissions = {};
  bool _loadingPermissions = true;
  String? _lastPermissionMessage;
  String _userName = 'Chargement...';
  String _userEmail = '';


  // Couleurs de l'entreprise
  final Color _primaryColor = Color(0xFF4CAF50); // Vert
  final Color _secondaryColor = Color(0xFFFF9800); // Orange
  final Color _darkPrimary = Color(0xFF388E3C); // Vert foncé
  final Color _lightPrimary = Color(0xFFC8E6C9); // Vert clair

  @override
  void initState() {
    super.initState();
    _mettreAJourPosition();
    _chargerPermissions();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _userName = data?['name'] ?? data?['displayName'] ?? 'Contrôleur';
            _userEmail = user.email ?? '';
          });
        } else {
          setState(() {
            _userName = 'Contrôleur';
            _userEmail = user.email ?? '';
          });
        }
      }
    } catch (e) {
      setState(() {
        _userName = 'Contrôleur';
        _userEmail = '';
      });
    }
  }

  // Données dynamiques
  List<DashboardItem> _getMenuItems() {
    final items = <DashboardItem>[];

    if (_userPermissions['planning'] == true) {
      items.add(DashboardItem(
        title: 'Planning (accordé)',
        icon: Icons.calendar_today_outlined,
        subtitle: 'Créer votre planning',
        moduleKey: 'planning',
      ));
    }

    if (_userPermissions['entreprises_&_taches'] == true) {
      items.add(DashboardItem(
        title: 'Entreprises & Tâches (accordé)',
        icon: Icons.apartment_outlined,
        subtitle: 'Créer et consulter vos entreprises et tâches',
        moduleKey: 'entreprises_&_taches',
      ));
    }

    if (_userPermissions['carte_interactive'] == true) {
      items.add(DashboardItem(
        title: 'Carte interactive (accordé)',
        icon: Icons.map_outlined,
        subtitle: 'Consulter les positions',
        moduleKey: 'carte_interactive',
      ));
    }

    if (_userPermissions['rapports'] == true) {
      items.add(DashboardItem(
        title: 'Rapports (accordé)',
        icon: Icons.analytics_outlined,
        subtitle: 'Creer vos fiche de rapport de terrein',
        moduleKey: 'rapports_simple',
      ));
    }

      // Toujours visible
      items.add(DashboardItem(
        title: 'Planning du jour',
        icon: Icons.calendar_view_day_outlined,
        subtitle: 'Voir mes affectations',
        moduleKey: 'Planning_du_jour',
      ));

      // Toujours visible
      items.add(DashboardItem(
        title: 'Mes tâches',
        icon: Icons.task_alt,
        subtitle: 'Consulter et effectuer mes tâches',
        moduleKey: 'Mes_tâches',
      ));

      // Toujours visible
      items.add(DashboardItem(
        title: 'Rapports',
        icon: Icons.note_alt_outlined,
        subtitle: 'Faire un rapport de terrain',
        moduleKey: 'Rapports',
      ));

    // Toujours visible
    items.add(DashboardItem(
      title: 'Messages',
      icon: Icons.note_alt_outlined,
      subtitle: 'Messagerie',
      moduleKey: 'Messages',
    ));

    // Toujours visible
    items.add(DashboardItem(
      title: 'Paramètres',
      icon: Icons.settings_outlined,
      subtitle: 'Configurer mon compte',
      moduleKey: 'Paramètres',
    ));

    return items;
  }

  // Données de statistiques
  final Map<String, dynamic> _stats = {
    'tasksCompleted': 12,
    'reportsSubmitted': 8,
    'ongoingTasks': 3,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_loadingPermissions) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Chargement de vos permissions..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile ? _buildMobileSidebar(context) : null,
      body: Row(
        children: [
          // Sidebar Desktop
          if (!isMobile) _buildDesktopSidebar(context),
          // Contenu principal
          Expanded(
            child: _buildMainContent(context, isMobile),
          ),
        ],
      ),
    );
  }

  Future<void> _mettreAJourPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          // Permission toujours refusée, affiche l'alerte
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Autorisation requise'),
                content: const Text(
                  'La géolocalisation est nécessaire pour pouvoir accéder sur l\'application.\n'
                      'Veuillez l\'autoriser dans les paramètres de l\'application.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      // Permission autorisée, on récupère et envoie la position
      final position = await Geolocator.getCurrentPosition();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lastUpdated': Timestamp.now(),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la mise à jour de la position : $e');
      }
    }
  }

  Future<void> _chargerPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = snap.data();
      if (data != null && data['permissions'] != null) {
        setState(() {
          _userPermissions = Map<String, bool>.from(data['permissions']);
          _lastPermissionMessage = data['lastPermissionMessage'];
          _loadingPermissions = false;
          _selectedIndex = 0;
        });
        // Afficher un message si présent
        if (_lastPermissionMessage != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lastPermissionMessage!),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        setState(() {
          _loadingPermissions = false;
          _selectedIndex = 0;
        });
      }
    }
  }


  Widget _buildDesktopSidebar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _sidebarExtended = true),
      onExit: (_) => setState(() => _sidebarExtended = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: _sidebarExtended ? 240 : 72,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.white,
          border: Border(
            right: BorderSide(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            _buildSidebarHeader(context),
            Expanded(
              child: ListView(
                children: _getMenuItems()
                    .asMap()
                    .entries
                    .map((entry) => _buildSidebarItem(context, entry.key, entry.value))
                    .toList(),
              ),
            ),
            _buildSidebarFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSidebar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      width: 240,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Column(
        children: [
          _buildSidebarHeader(context),
          Expanded(
            child: ListView(
              children: _getMenuItems()
                  .asMap()
                  .entries
                  .map((entry) => _buildSidebarItem(context, entry.key, entry.value))
                  .toList(),
            ),
          ),
          _buildSidebarFooter(context, isMobile: true),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(isDarkMode ? 0.2 : 0.1),
        border: Border(
          bottom: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, size: 28, color: _primaryColor),
          if (_sidebarExtended) ...[
            SizedBox(width: 12),
            Text(
              'Contrôleur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index, DashboardItem item) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Tooltip(
        message: !_sidebarExtended && !isMobile ? item.title : '',
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
            if (isMobile) Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? _lightPrimary.withOpacity(isDarkMode ? 0.3 : 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: _primaryColor.withOpacity(0.5), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      size: 22,
                      color: isSelected
                          ? _primaryColor
                          : isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    if (item.notificationCount > 0)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: _secondaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            item.notificationCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_sidebarExtended || isMobile) ...[
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? _primaryColor
                                : isDarkMode
                                ? Colors.grey[300]
                                : Colors.grey[800],
                          ),
                        ),
                        if (_sidebarExtended || isMobile)
                          Text(
                            item.subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context, {bool isMobile = false}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    void navigateToProfile() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProfilePage(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 16.0, right: 16.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: navigateToProfile,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _primaryColor.withOpacity(0.2),
                    child: Icon(Icons.person_outline, color: _primaryColor),
                  ),
                  if (_sidebarExtended || isMobile) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Connecté',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ],
                ],
              ),
            ),
          ),

          if (!isMobile)
            SizedBox(height: 16),
          if (!isMobile)
            OutlinedButton.icon(
              onPressed: () => setState(() => _sidebarExtended = !_sidebarExtended),
              icon: Icon(
                _sidebarExtended ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: _primaryColor,
              ),
              label: _sidebarExtended ? Text(
                'Réduire',
                style: TextStyle(color: _primaryColor),
              ) : SizedBox(),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: _primaryColor.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final currentItem = _getMenuItems()[_selectedIndex];

    return Column(
      children: [
        if (isMobile)
          AppBar(
            backgroundColor: _primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            title: Text(
              currentItem.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.logout, color: Colors.white),
                tooltip: 'Se déconnecter',
                onPressed: () => _confirmLogout(context),
              ),
              SizedBox(width: 8),
            ],
          ),
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile)
                  Text(
                    currentItem.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                SizedBox(height: 8),
                if (!isMobile)
                  Text(
                    currentItem.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                SizedBox(height: 24),

                SizedBox(height: 24),
                // Contenu principal
                Expanded(
                  child: _buildContentForIndex(_selectedIndex),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildStatCard(
      BuildContext context, {
        required String title,
        required int value,
        required IconData icon,
        required Color color,
      }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value.toString(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color, // Utilisation de la couleur principale pour la valeur
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentForIndex(int index) {
    final moduleKey = _getMenuItems()[index].moduleKey;
    switch (moduleKey) {
      case 'Planning_du_jour': // Planning du jour
        return const TachesDuJourPage();
      case 'Mes_tâches': // Mes Tâches
        return const PlanningSemainePersonnel();
      case 'Rapports': // Rapports
        return const ControllerFillFichePage();
      case 'Messages': // Messages
        return const MessagePage();

      //Lorsque les permissions seront accordées
      case 'planning': // Planning (accordé)
        return const PlanningPage();
      case 'entreprises_&_taches': // Entreprises & taches (accordés)
        return const GererEntreprisesPage();
      case 'carte_interactive':// Carte interactive (accordé)
        return const LocalisationPage();
      case 'rapports_simple': // Rapports (accordé)
        return const CreationFicheControlePage();
      default:
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getMenuItems()[index].icon,
                      size: 48,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Contenu pour ${_getMenuItems()[index].title}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _getMenuItems()[index].subtitle,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {},
                    child: Text('Accéder'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/wrapper', (_) => false); // Redirige vers la Wrapper
      }
    }
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final String subtitle;
  final String moduleKey;
  final int notificationCount;

  DashboardItem({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.moduleKey,
    this.notificationCount = 0,
  });
}
