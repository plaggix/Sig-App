import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sig_app/creer_planning_page.dart';
import 'package:sig_app/rapport_admin.dart';
import 'consulteractivite_page.dart';
import 'package:sig_app/consulter_entreprise.dart';

import 'gestion_controleur.dart';
import 'gestion_permissions.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    AdminDashboard(),
    ControllerDashboard(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF1A1A1A),
        selectedItemColor: Color(0xFFE50914),
        unselectedItemColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Contrôleur'),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isSidebarExtended = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Couleurs de l'entreprise
  final Color _primaryColor = Color(0xFF4CAF50); // Vert
  final Color _secondaryColor = Color(0xFFFF9800); // Orange
  final Color _darkPrimary = Color(0xFF388E3C); // Vert foncé
  final Color _lightPrimary = Color(0xFFC8E6C9); // Vert clair

  // Données de la sidebar
  final List<SidebarItem> _sidebarItems = [
    SidebarItem(
      title: 'Tableau de bord',
      icon: Icons.dashboard_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Contrôleurs',
      icon: Icons.supervised_user_circle_outlined,
      notificationCount: 3,
    ),
    SidebarItem(
      title: 'Planning',
      icon: Icons.calendar_today_outlined,
      notificationCount: 5,
    ),
    SidebarItem(
      title: 'Carte interactive',
      icon: Icons.map_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Tâches',
      icon: Icons.task_outlined,
      notificationCount: 12,
    ),
    SidebarItem(
      title: 'Entreprises',
      icon: Icons.apartment_outlined,
      notificationCount: 2,
    ),
    SidebarItem(
      title: 'Permissions',
      icon: Icons.security_outlined,
      notificationCount: 0,
    ),
    SidebarItem(
      title: 'Rapports',
      icon: Icons.analytics_outlined,
      notificationCount: 7,
    ),
    SidebarItem(
      title: 'Messages',
      icon: Icons.message_outlined,
      notificationCount: 9,
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
              'Admin Pro',
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
          Row(
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
                        'Admin User',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Administrateur',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
              label: _isSidebarExtended ? Text('Réduire', style: TextStyle(color: _primaryColor)) : SizedBox(),
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
      case 1: // Contrôleurs
        return GestionControleurPage();
      case 2: // Planning
        return PlanningPage();
      case 4: // Tâches
        return ConsulterActivitePage();
      case 5: // Entreprises
        return GererEntreprisesTachesPage();
      case 6: // Permissions
        return GestionPermissionsPage();
      case 7: // Rapports
        return AdminRapportsPage();
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

class ControllerDashboard extends StatefulWidget {
  @override
  _ControllerDashboardState createState() => _ControllerDashboardState();
}

class _ControllerDashboardState extends State<ControllerDashboard> {
  int _selectedIndex = 0;
  bool _sidebarExtended = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Couleurs de l'entreprise
  final Color _primaryColor = Color(0xFF4CAF50); // Vert
  final Color _secondaryColor = Color(0xFFFF9800); // Orange
  final Color _darkPrimary = Color(0xFF388E3C); // Vert foncé
  final Color _lightPrimary = Color(0xFFC8E6C9); // Vert clair

  // Données dynamiques
  final List<DashboardItem> _menuItems = [
    DashboardItem(
      title: 'Planning du jour',
      icon: Icons.calendar_view_day_outlined,
      subtitle: 'Voir mes affectations',
      notificationCount: 2,
    ),
    DashboardItem(
      title: 'Mes tâches',
      icon: Icons.task_alt,
      subtitle: 'Consulter et effectuer mes tâches',
      notificationCount: 5,
    ),
    DashboardItem(
      title: 'Rapports',
      icon: Icons.note_alt_outlined,
      subtitle: 'Faire un rapport de terrain',
      notificationCount: 1,
    ),
    DashboardItem(
      title: 'Carte interactive',
      icon: Icons.map_outlined,
      subtitle: 'Visualiser les interventions',
      notificationCount: 0,
    ),
    DashboardItem(
      title: 'Historique',
      icon: Icons.history,
      subtitle: 'Voir mes activités passées',
      notificationCount: 0,
    ),
    DashboardItem(
      title: 'Paramètres',
      icon: Icons.settings_outlined,
      subtitle: 'Configurer mon compte',
      notificationCount: 0,
    ),
  ];

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
                children: _menuItems
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
              children: _menuItems
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
          Row(
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
                        'Contrôleur',
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
                Icon(Icons.more_vert, size: 20, color: Colors.grey),
              ],
            ],
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
    final currentItem = _menuItems[_selectedIndex];

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
                // Statistiques (uniquement sur la page d'accueil)
                if (_selectedIndex == 0) _buildStatsCards(context),
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

  Widget _buildStatsCards(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 3,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: MediaQuery.of(context).size.width < 600 ? 3 : 1.5,
      children: [
        _buildStatCard(
          context,
          title: 'Tâches terminées',
          value: _stats['tasksCompleted'],
          icon: Icons.check_circle_outlined,
          color: _primaryColor,
        ),
        _buildStatCard(
          context,
          title: 'Rapports soumis',
          value: _stats['reportsSubmitted'],
          icon: Icons.assignment_turned_in_outlined,
          color: _secondaryColor,
        ),
        _buildStatCard(
          context,
          title: 'Tâches en cours',
          value: _stats['ongoingTasks'],
          icon: Icons.hourglass_top_outlined,
          color: Colors.blue, // Gardé bleu pour différenciation
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
                  _menuItems[index].icon,
                  size: 48,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Contenu pour ${_menuItems[index].title}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 12),
              Text(
                _menuItems[index].subtitle,
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

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final int notificationCount;

  DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.notificationCount = 0,
  });
}

class SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 5,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text('Page "$title" en construction...',
            style: TextStyle(fontSize: 18, color: Colors.white70)),
      ),
    );
  }
}
