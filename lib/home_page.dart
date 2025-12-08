/* import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:sig_app/consulter_entreprise.dart';
import 'package:sig_app/consulter_planning_page.dart';
import 'package:sig_app/creer_planning_page.dart';
import 'package:sig_app/planning_personnel.dart';
import 'package:sig_app/welcome.dart';
import 'consulteractivite_page.dart';
import 'profile_page.dart';
import 'notification_page.dart';
import 'pages/settings/parametre_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/welcome1.png', height: 30),
            const SizedBox(width: 10),
            const Text('SIG', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green[700],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          _buildQuickAccessMenu(),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: const HomeContent(),
      ),
      drawer: _buildNavigationDrawer(),
    );
  }

  Widget _buildQuickAccessMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        print('Selected: $value');
        if (value == 'settings') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParametrePage()),
          );
        } else if (value == 'notifications') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatPage(peerUid: '', peerName: '', peerPhoto: '',)),
          );
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings, color: Colors.orange[700]),
            title: const Text('Paramètres'),
          ),
        ),
        PopupMenuItem(
          value: 'notifications',
          child: ListTile(
            leading: Icon(Icons.notifications, color: Colors.blue[700]),
            title: const Text('Notifications'),
          ),
        ),
      ],
    );
  }


  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[800]!, Colors.green[600]!],
              ),
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.green[700]),
                  ),
                  const SizedBox(height: 10),
                  const Text('Bienvenue', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          _buildExpansionTile(
            icon: Icons.task,
            title: 'Tâches et Entreprises',
            children: [
              _buildDrawerItem('Consulter les activités', Icons.list, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConsulterActivitePage()),
                );
              }),
              _buildDrawerItem('Consulter les entreprises', Icons.list, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GererEntreprisesPage()),
                );
              }),
            ],
          ),
          _buildExpansionTile(
            icon: Icons.calendar_today,
            title: 'Planning',
            children: [
              _buildDrawerItem('Créer un planning', Icons.add, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PlanningPage()),
                );
              }),
              _buildDrawerItem('Consulter le planning', Icons.view_agenda, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConsulterPlanning()),
                );
              }),
              _buildDrawerItem('Mon planning', Icons.view_agenda, () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PersonalPlanningPage()),
                );
              }),
            ],
          ),
          _buildDrawerItem('Localisation', Icons.location_on, () {}),
          _buildExpansionTile(
            icon: Icons.assessment,
            title: 'Rapports',
            children: [
              _buildDrawerItem('Faire un rapport', Icons.create, () {}),
              _buildDrawerItem('Consulter les rapports', Icons.library_books, () {}),
            ],
          ),
          _buildDrawerItem('Notifications', Icons.notifications, () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatPage(peerUid: '', peerName: '', peerPhoto: '',)),
            );
          }),

          _buildDrawerItem('Paramètres', Icons.settings, () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ParametrePage()),
            );
          }),

          const Divider(),
          _buildDrawerItem('Déconnexion', Icons.exit_to_app, () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => WelcomePage()),
            );
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildExpansionTile({required IconData icon, required String title, required List<Widget> children}) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.green[700]),
      title: Text(title, style: TextStyle(color: Colors.green[800])),
      children: children,
    );
  }

  Widget _buildDrawerItem(String title, IconData icon, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.green[700]),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      onTap: onTap,
    );
  }
}

class HomeContent extends StatelessWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 20),
          _buildQuickActionsGrid(),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[600]!, Colors.green[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            Text(
              'Bienvenue !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Que souhaitez-vous faire aujourd\'hui ?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildActionCard(Icons.task, 'Tâches', Colors.green),
        _buildActionCard(Icons.calendar_today, 'Planning', Colors.orange),
        _buildActionCard(Icons.location_on, 'Localisation', Colors.blue),
        _buildActionCard(Icons.assessment, 'Rapports', Colors.purple),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}*/
