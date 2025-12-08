import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sig_app/creer_planning_page.dart';
import 'package:sig_app/profile_page.dart';
import 'package:sig_app/rapport_admin.dart';
import 'acceuil_page.dart';
import 'consulteractivite_page.dart';
import 'package:sig_app/consulter_entreprise.dart';
import 'gestion_controleur.dart';
import 'gestion_permissions.dart';
import 'localisation_page.dart';
import 'message_page.dart';
import 'tendances_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarExtended = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.displayName ?? 'Gestionnaire';
          _userEmail = user.email ?? '';
        });
      } else {
        setState(() {
          _userName = 'Non connecté';
          _userEmail = '';
        });
      }
    } catch (e) {
      setState(() {
        _userName = 'Erreur';
        _userEmail = '';
      });
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
        Navigator.of(context).pushNamedAndRemoveUntil('/wrapper', (_) => false); // Redirige vers la page Wrapper
      }
    }
  }

  // Données de la sidebar
  final List<SidebarItem> _sidebarItems = [
    SidebarItem(
      title: 'Acceuil',
      icon: Icons.dashboard_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Contrôleurs',
      icon: Icons.supervised_user_circle_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Planning',
      icon: Icons.calendar_today_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Entreprises & Tâches',
      icon: Icons.apartment_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Permissions',
      icon: Icons.security_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Rapports',
      icon: Icons.analytics_outlined,
      notificationCount: 0,
    ),
    
    SidebarItem(
      title: 'Messages',
      icon: Icons.message_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Paramètres',
      icon: Icons.settings_outlined,
      notificationCount: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
      drawer: isMobile ? _buildMobileSidebar(context) : null,
      body: Row(
        children: [
          // Sidebar - Visible sur desktop
          if (!isMobile) _buildDesktopSidebar(context),
          // Contenu principal
          Expanded(
            child: _buildMainContent(context, isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isSidebarExtended = true),
      onExit: (_) => setState(() => _isSidebarExtended = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: _isSidebarExtended ? 250 : 80,
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
              child: SingleChildScrollView(
                child: Column(
                  children: _sidebarItems
                      .asMap()
                      .entries
                      .map((entry) => _buildSidebarItem(context, entry.key, entry.value))
                      .toList(),
                ),
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
      width: 250,
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      child: Column(
        children: [
          _buildSidebarHeader(context),
          Expanded(
            child: ListView(
                children: _sidebarItems
                    .asMap()
                    .entries
                    .map((entry) => _buildSidebarItem(context, entry.key, entry.value))
                    .toList()),
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
          Icon(Icons.admin_panel_settings, size: 28, color: _primaryColor),
          if (_isSidebarExtended) ...[
            SizedBox(width: 12),
            Text(
              'Gestionnaire',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebarItem(BuildContext context, int index, SidebarItem item) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
      child: Tooltip(
        message: !_isSidebarExtended && !isMobile ? item.title : '',
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
                if (_isSidebarExtended || isMobile) ...[
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
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
      padding: EdgeInsets.all(16),
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
                  if (_isSidebarExtended || isMobile) ...[
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
                          if (_userEmail.isNotEmpty)
                            Text(
                              _userEmail,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (_isSidebarExtended || isMobile)
                    Icon(Icons.chevron_right,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                ],
              ),
            ),
          ),

          if (!isMobile) SizedBox(height: 16),
          if (!isMobile)
            OutlinedButton.icon(
              onPressed: () => setState(() => _isSidebarExtended = !_isSidebarExtended),
              icon: Icon(
                _isSidebarExtended ? Icons.chevron_left : Icons.chevron_right,
                size: 18,
                color: _primaryColor,
              ),
              label: _isSidebarExtended ?
              Text('Réduire', style: TextStyle(color: _primaryColor)) :
              SizedBox(),
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
              _sidebarItems[_selectedIndex].title,
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
                    _sidebarItems[_selectedIndex].title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                SizedBox(height: 16),
                Expanded(
                  // Affiche la page correspondante en fonction de l'index sélectionné
                  child: _getPageForSelectedIndex(_selectedIndex),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _getPageForSelectedIndex(int index) {
    switch(index) {
      case 0: // Acceuil
        return AccueilPage();
      case 1: // Contrôleurs
        return GestionControleurPage();
      case 2: // Planning
        return PlanningPage();
      case 3: // Entreprises & Tâches
        return GererEntreprisesPage();
      case 4: // Permissions
        return GestionPermissionsPage();
      case 5: // Rapports
        return CreationFicheControlePage();
      case 6: // Tendances IA
        return TendancesPage();
      case 7: // Messages
        return MessagePage();
      default:
        return _buildDefaultContent(index);
    }
  }

  Widget _buildDefaultContent(int index) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _sidebarItems[index].icon,
              size: 64,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Contenu pour ${_sidebarItems[index].title}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: _primaryColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Cette section affichera les données et fonctionnalités spécifiques',
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
    );
  }
}

class SidebarItem {
  final String title;
  final IconData icon;
  final int notificationCount;

  SidebarItem({
    required this.title,
    required this.icon,
    this.notificationCount = 0,
  });
}