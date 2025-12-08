import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanningSemainePersonnel extends StatefulWidget {
  const PlanningSemainePersonnel({super.key});

  @override
  State<PlanningSemainePersonnel> createState() => _PlanningSemainePersonnelState();
}

class _PlanningSemainePersonnelState extends State<PlanningSemainePersonnel> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _plannings = [];
  bool _loading = true;
  bool _refreshing = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

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

    _loadPlannings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPlannings() async {
    if (_currentUser == null) return;

    setState(() => _refreshing = true);

    final userPlanningSnapshot = await _firestore
        .collection('user_plannings')
        .doc(_currentUser!.uid)
        .collection('plannings')
        .get();

    final List<Map<String, dynamic>> allTasks = [];

    // 🔹 Définir la semaine en cours (du lundi au samedi)
    final now = DateTime.now();
    final lundi = now.subtract(Duration(days: now.weekday - 1));
    final samedi = lundi.add(const Duration(days: 5));

    for (final doc in userPlanningSnapshot.docs) {
      final data = doc.data();
      final jours = data['jours'] as Map<String, dynamic>?;

      if (jours != null) {
        jours.forEach((jour, activities) {
          if (activities is List) {
            for (final item in activities) {
              final date = (item['date'] as Timestamp?)?.toDate() ?? _getDateFromJour(jour);

              // 🔹 Filtrer uniquement les activités de la semaine en cours
              if (date.isAfter(lundi.subtract(const Duration(days: 1))) &&
                  date.isBefore(samedi.add(const Duration(days: 1)))) {
                allTasks.add({
                  'id': item['id'] ?? doc.id,
                  'tache': item['tache'] ?? item['activite'] ?? 'Tâche sans nom',
                  'entreprise': item['sousAgence'] ?? item['entreprise'] ?? 'Entreprise non précisée',
                  'date': Timestamp.fromDate(date),
                  'statut': item['statut'] ?? (item['effectue'] == true ? 'terminee' : 'en_attente'),
                  'jour': jour,
                  'effectue': item['effectue'] ?? false,
                });
              }
            }
          }
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _plannings = allTasks;
      _loading = false;
      _refreshing = false;
    });

    _animationController.forward();
  }

  DateTime _getDateFromJour(String jour) {
    final now = DateTime.now();
    final lundi = now.subtract(Duration(days: now.weekday - 1));
    final joursMap = {
      'Lundi': 0,
      'Mardi': 1,
      'Mercredi': 2,
      'Jeudi': 3,
      'Vendredi': 4,
      'Samedi': 5,
    };
    final offset = joursMap[jour] ?? 0;
    return lundi.add(Duration(days: offset));
  }



  Future<void> _changerStatut(Map<String, dynamic> planning, String nouveauStatut) async {
    try {
      final idChamp = planning['id']; // UUID du planning
      if (_currentUser == null) return;

      final bool estTerminee = nouveauStatut == 'terminee';

      // 🔹 1. Mettre à jour la collection globale "plannings"
      final query = await _firestore
          .collection('plannings')
          .where('id', isEqualTo: idChamp)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune tâche correspondante trouvée pour mise à jour.')),
        );
        return;
      }

      final docRef = query.docs.first.reference;
      await docRef.update({
        'statut': nouveauStatut,
        'effectue': estTerminee,
      });

      // 🔹 2. Synchroniser aussi dans la collection "user_plannings"
      final userPlanningRef = _firestore
          .collection('user_plannings')
          .doc(_currentUser!.uid)
          .collection('plannings')
          .doc(idChamp);

      final userDoc = await userPlanningRef.get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final jours = data['jours'] as Map<String, dynamic>?;

        if (jours != null) {
          // Met à jour le statut de la tâche dans la bonne journée
          jours.forEach((jour, tasks) {
            if (tasks is List) {
              for (var i = 0; i < tasks.length; i++) {
                final t = tasks[i];
                if (t is Map<String, dynamic> && t['id'] == idChamp) {
                  t['statut'] = nouveauStatut;
                  t['effectue'] = estTerminee;
                  tasks[i] = t;
                }
              }
            }
          });

          await userPlanningRef.update({'jours': jours});
        }
      }

      // ✅ 3. Correction : mettre à jour localement sans 'data'
      setState(() {
        for (var i = 0; i < _plannings.length; i++) {
          final p = _plannings[i];
          if (p['id'] == idChamp) {
            _plannings[i]['statut'] = nouveauStatut;
            _plannings[i]['effectue'] = estTerminee;
          }
        }
      });

      // 🔹 4. Feedback utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tâche marquée comme ${estTerminee ? "terminée" : "inachevée"}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: estTerminee ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

    } catch (e) {
      debugPrint('Erreur changement statut: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    // Grouper par jour
    final joursSemaine = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final jour in joursSemaine) {
      grouped[jour] = _plannings.where((p) => p['jour'] == jour).toList();
    }

    // Obtenir la semaine actuelle
    final now = DateTime.now();
    final debutSemaine = now.subtract(Duration(days: now.weekday - 1));
    final finSemaine = debutSemaine.add(const Duration(days: 6));
    final formatter = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mon Planning',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              const SizedBox(height: 4),
              Text(
                '${formatter.format(debutSemaine)} - ${formatter.format(finSemaine)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        toolbarHeight: 90,
        actions: [
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
            onPressed: _loadPlannings,
            tooltip: 'Actualiser le planning',
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingState()
          : LayoutBuilder(
        builder: (context, constraints) {
          if (isWideScreen) {
            return _buildDesktopLayout(grouped, debutSemaine, finSemaine);
          } else {
            return _buildMobileLayout(grouped, debutSemaine, finSemaine);
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
              const Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chargement de votre planning...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
      Map<String, List<Map<String, dynamic>>> grouped,
      DateTime debutSemaine,
      DateTime finSemaine) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _plannings.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
          onRefresh: _loadPlannings,
          color: const Color(0xFF2E7D32),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWeekHeader(debutSemaine, finSemaine),
              const SizedBox(height: 16),
              ...grouped.entries.map((entry) {
                final jour = entry.key;
                final items = entry.value;
                if (items.isEmpty) return const SizedBox();
                return JourPlanningCard(
                  jour: jour,
                  items: items,
                  onStatusChange: _changerStatut,
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
      Map<String, List<Map<String, dynamic>>> grouped,
      DateTime debutSemaine,
      DateTime finSemaine) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _plannings.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
          onRefresh: _loadPlannings,
          color: const Color(0xFF2E7D32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne gauche - Liste des jours
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _buildWeekHeader(debutSemaine, finSemaine),
                      const SizedBox(height: 16),
                      ...grouped.entries.map((entry) {
                        final jour = entry.key;
                        final items = entry.value;
                        if (items.isEmpty) return const SizedBox();
                        return JourPlanningCard(
                          jour: jour,
                          items: items,
                          onStatusChange: _changerStatut,
                          compact: true,
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Colonne droite - Détails des tâches (premier jour développé)
                Expanded(
                  flex: 2,
                  child: _buildTasksDetailView(grouped),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekHeader(DateTime debutSemaine, DateTime finSemaine) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: const Color(0xFF2E7D32), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Semaine du ${DateFormat('dd MMMM', 'fr_FR').format(debutSemaine)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    '${DateFormat('dd MMM', 'fr_FR').format(debutSemaine)} - ${DateFormat('dd MMM yyyy', 'fr_FR').format(finSemaine)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_plannings.length} tâche${_plannings.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksDetailView(Map<String, List<Map<String, dynamic>>> grouped) {
    final firstNonEmptyDay = grouped.entries.firstWhere(
          (entry) => entry.value.isNotEmpty,
      orElse: () => grouped.entries.first,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Détails des tâches - ${firstNonEmptyDay.key}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: firstNonEmptyDay.value.length,
                itemBuilder: (context, index) {
                  return TacheTile(
                    planning: firstNonEmptyDay.value[index],
                    onStatusChange: _changerStatut,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 100,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune tâche cette semaine',
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
              'Profitez de cette semaine plus légère ou planifiez de nouvelles activités',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 24),

        ],
      ),
    );
  }
}

class JourPlanningCard extends StatefulWidget {
  final String jour;
  final List<Map<String, dynamic>> items;
  final Function(Map<String, dynamic>, String) onStatusChange;
  final bool compact;

  const JourPlanningCard({
    super.key,
    required this.jour,
    required this.items,
    required this.onStatusChange,
    this.compact = false,
  });

  @override
  State<JourPlanningCard> createState() => _JourPlanningCardState();
}

class _JourPlanningCardState extends State<JourPlanningCard> with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _heightAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );

    // Développer automatiquement si c'est aujourd'hui
    final date = _getDateFromJour(widget.jour);
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    if (isToday) {
      _isExpanded = true;
      _expandController.forward();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  DateTime _getDateFromJour(String jour) {
    final now = DateTime.now();
    final lundi = now.subtract(Duration(days: now.weekday - 1));
    final joursMap = {
      'Lundi': 0,
      'Mardi': 1,
      'Mercredi': 2,
      'Jeudi': 3,
      'Vendredi': 4,
      'Samedi': 5,
    };
    final offset = joursMap[jour] ?? 0;
    return lundi.add(Duration(days: offset));
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  int getCompletedTasksCount() {
    return widget.items.where((item) => item['statut'] == 'terminee').length;
  }

  @override
  Widget build(BuildContext context) {
    final date = _getDateFromJour(widget.jour);
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    final completedCount = getCompletedTasksCount();
    final totalCount = widget.items.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _toggleExpansion,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // En-tête du jour
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFF2E7D32).withOpacity(0.1)
                            : Theme.of(context).colorScheme.surfaceVariant,
                        shape: BoxShape.circle,
                        border: isToday
                            ? Border.all(color: const Color(0xFF2E7D32), width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? const Color(0xFF2E7D32)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.jour,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? const Color(0xFF2E7D32)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isToday
                                ? 'Aujourd\'hui • ${DateFormat('EEEE', 'fr_FR').format(date)}'
                                : DateFormat('EEEE', 'fr_FR').format(date),
                            style: TextStyle(
                              fontSize: 13,
                              color: isToday
                                  ? const Color(0xFF2E7D32).withOpacity(0.7)
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          if (!widget.compact) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress.toDouble(),
                              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF2E7D32).withOpacity(0.1)
                                : Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$completedCount/$totalCount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? const Color(0xFF2E7D32)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),

                // Contenu développable
                SizeTransition(
                  sizeFactor: _heightAnimation,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      ...widget.items.map((planning) {
                        return TacheTile(
                          planning: planning,
                          onStatusChange: widget.onStatusChange,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TacheTile extends StatelessWidget {
  final Map<String, dynamic> planning;
  final Function(Map<String, dynamic>, String) onStatusChange;

  const TacheTile({
    super.key,
    required this.planning,
    required this.onStatusChange,
  });

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'terminee':
        return Colors.green;
      case 'inachevee':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBackgroundColor(String statut) {
    switch (statut) {
      case 'terminee':
        return Colors.green.withOpacity(0.1);
      case 'inachevee':
        return Colors.orange.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  IconData _getStatusIcon(String statut) {
    switch (statut) {
      case 'terminee':
        return Icons.check_circle_rounded;
      case 'inachevee':
        return Icons.pending_rounded;
      default:
        return Icons.access_time_rounded;
    }
  }

  String _getStatusText(String statut) {
    switch (statut) {
      case 'terminee':
        return 'Terminée';
      case 'inachevee':
        return 'En pause';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateTache = (planning['date'] as Timestamp).toDate();
    final statut = planning['statut'] ?? 'en_attente';
    final statusColor = _getStatusColor(statut);
    final backgroundColor = _getStatusBackgroundColor(statut);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Semantics(
            label: 'Statut: ${_getStatusText(statut)}',
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(statut),
                color: statusColor,
                size: 22,
              ),
            ),
          ),
          title: Text(
            planning['tache'] ?? planning['activite'] ?? 'Tâche sans nom',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                planning['entreprise'],
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('HH:mm').format(dateTache),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(statut),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            onSelected: (value) => onStatusChange(planning, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'terminee',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    const Text('Marquer comme terminée'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'inachevee',
                child: Row(
                  children: [
                    Icon(Icons.pause_circle, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    const Text('Marquer comme inachevée'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}