import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'planning_semaine_personnel.dart';
import 'historiques_non_termine.dart';


class TachesDuJourPage extends StatefulWidget {
  const TachesDuJourPage({super.key});

  @override
  State<TachesDuJourPage> createState() => _TachesDuJourPageState();
}

class _TachesDuJourPageState extends State<TachesDuJourPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _tachesDuJour = [];
  bool _loading = true;
  bool _hasInachevees = false;
  bool _refreshing = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _notificationAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _notificationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 🔹 Initialisation des locales françaises avant de charger les données
    initializeDateFormatting('fr_FR', null).then((_) {
      _loadTaches();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTaches() async {
    if (_currentUser == null) return;

    setState(() {
      _refreshing = true;
      _loading = true;
    });

    final todayName = DateFormat('EEEE', 'fr_FR').format(DateTime.now());
    final joursMap = {
      'lundi': 'Lundi',
      'mardi': 'Mardi',
      'mercredi': 'Mercredi',
      'jeudi': 'Jeudi',
      'vendredi': 'Vendredi',
      'samedi': 'Samedi',
      'dimanche': 'Dimanche',
    };
    final today = joursMap[todayName.toLowerCase()] ?? todayName;

    try {
      final snapshot = await _firestore
          .collection('user_plannings')
          .doc(_currentUser!.uid)
          .collection('plannings')
          .get();

      List<Map<String, dynamic>> displayedTasks = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final jours = data['jours'] as Map<String, dynamic>?;

        if (jours == null) continue;

        for (final entry in jours.entries) {
          final jour = entry.key;
          final tasks = entry.value;

          if (tasks is List) {
            for (final item in tasks) {
              final statut = (item['statut'] ?? '').toString().toLowerCase();

              // 🔹 On garde :
              // 1. les tâches du jour courant qui ne sont pas terminées
              // 2. les tâches précédentes marquées "inachevée"
              final isToday = jour == today;
              final isInachevee = statut == 'inachevee';
              final isTerminee = statut == 'terminee';

              if ((isToday && !isTerminee) || (!isToday && isInachevee)) {
                displayedTasks.add({
                  'id': item['id'] ?? doc.id,
                  'tache': item['tache'] ?? item['activite'] ?? 'Tâche inconnue',
                  'entreprise': item['entreprise'] ?? 'Entreprise non précisée',
                  'statut': statut.isEmpty ? 'en_attente' : statut,
                  'jour': jour,
                });
              }
            }
          }
        }
      }

      setState(() {
        _tachesDuJour = displayedTasks;
        _loading = false;
        _refreshing = false;
      });

      _animationController.forward();
    } catch (e) {
      debugPrint('Erreur chargement tâches : $e');
      setState(() {
        _loading = false;
        _refreshing = false;
      });
      _showErrorSnackbar('Erreur de chargement : $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _goToWeeklyPlanning() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlanningSemainePersonnel()),
    );
  }

  void _markNotificationAsRead() {
    setState(() {
      _hasInachevees = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    final today = DateFormat('EEEE d MMMM y', 'fr_FR').format(DateTime.now());

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mes tâches du jour',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              const SizedBox(height: 4),
              Text(
                today,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Color(0xFF2E7D32),
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        toolbarHeight: 90,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: _goToWeeklyPlanning,
            tooltip: 'Voir planning de la semaine',
          ),

           IconButton(
             icon: const Icon(Icons.history_rounded, color: Colors.white),
             tooltip: 'Tâches non terminées',
             onPressed: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(
                   builder: (_) => const HistoriquesNonTerminePage(),
                  ),
                );
              },
            ),

          _refreshing
              ? Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          )
              : IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTaches,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : LayoutBuilder(
        builder: (context, constraints) {
          if (isWideScreen) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de vos tâches...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Notification tâches inachevées
              if (_hasInachevees) _buildNotificationBanner(),

              // En-tête avec compteur de tâches
              _buildHeaderSection(context),
              const SizedBox(height: 16),

              // Liste des tâches du jour
              Expanded(
                child: _tachesDuJour.isEmpty
                    ? _buildEmptyState()
                    : _buildTasksList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne gauche - Résumé et alertes
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    if (_hasInachevees) _buildNotificationBanner(),
                    const SizedBox(height: 16),
                    _buildHeaderSection(context),
                    const SizedBox(height: 24),
                    _buildProgressCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Colonne droite - Liste des tâches
              Expanded(
                flex: 2,
                child: _tachesDuJour.isEmpty
                    ? _buildEmptyState()
                    : _buildTasksList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return ScaleTransition(
      scale: _notificationAnimation,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.orange.shade50,
              Colors.orange.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Tâches inachevées",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Vous avez des tâches non terminées hier.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                TextButton(
                  onPressed: _goToWeeklyPlanning,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: const Text("Voir",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _markNotificationAsRead,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text("Masquer",
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    // Calcul du nombre de tâches terminées et du total
    final completedTasks =
        _tachesDuJour.where((task) => task['statut'] == 'terminee').length;
    final totalTasks = _tachesDuJour.length;

    // Progression sous forme de double pour LinearProgressIndicator
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.task_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tachesDuJour.isEmpty
                        ? "Aucune tâche aujourd'hui"
                        : "Progression du jour",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (_tachesDuJour.isNotEmpty)
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "$completedTasks/$totalTasks terminées",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            if (_tachesDuJour.isNotEmpty) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildProgressCard() {
    final completedTasks = _tachesDuJour.where((task) => task['statut'] == 'terminee').length;
    final pendingTasks = _tachesDuJour.where((task) => task['statut'] == 'en_attente').length;
    final inProgressTasks = _tachesDuJour.where((task) => task['statut'] == 'inachevee').length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatItem('Terminées', completedTasks, Colors.green),
            _buildStatItem('En attente', pendingTasks, Colors.grey),
            _buildStatItem('En cours', inProgressTasks, Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList() {
    return ListView.builder(
      itemCount: _tachesDuJour.length,
      itemBuilder: (context, index) {
        final task = _tachesDuJour[index];
        return TacheCard(
          task: task,
          onTap: () {
            // Action pour modifier la tâche
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            "Aucune tâche programmée",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Profitez de votre journée ou consultez votre planning hebdomadaire",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _goToWeeklyPlanning,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Voir le planning de la semaine"),
          ),
        ],
      ),
    );
  }
}

class TacheCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  const TacheCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statut = (task['statut'] ?? '').toString().toLowerCase();
    late final Color statusColor;
    late final IconData statusIcon;
    late final String statusText;

    switch (statut) {
      case 'terminee':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Terminée';
        break;
      case 'inachevee':
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle_filled_rounded;
        statusText = 'En pause';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.access_time_rounded;
        statusText = 'En attente';
    }

    final tache = task['tache'] ?? 'Tâche inconnue';
    final entreprise = task['sousAgence'] ?? task['entreprise'] ?? 'Entreprise non précisée';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          title: Text(
            tache,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entreprise,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        ),
      ),
    );
  }
}