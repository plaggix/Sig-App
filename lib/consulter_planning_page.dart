import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ConsulterPlanning extends StatefulWidget {
  const ConsulterPlanning({super.key});

  @override
  State<ConsulterPlanning> createState() => _ConsulterPlanningState();
}

class _ConsulterPlanningState extends State<ConsulterPlanning> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _groupedPlannings = [];
  Map<String, String> _controleurNames = {};
  bool _loading = true;

  // Sélection pour suppression multiple
  Set<String> _selectedPlannings = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Design System Material 3
  ColorScheme get _colorScheme => ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    brightness: Theme.of(context).brightness,
  );

  static const double _cardRadius = 16.0;
  static const double _elementSpacing = 16.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _chargerDonnees().then((_) {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _loading = true);

    final controleurSnap = await _firestore.collection('users').where('role', isEqualTo: 'contrôleur').get();
    for (var doc in controleurSnap.docs) {
      _controleurNames[doc.id] = doc['name'] ?? 'Sans nom';
    }

    final snap = await _firestore.collection('plannings').orderBy('date', descending: false).get();
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final doc in snap.docs) {
      final data = doc.data();
      final weekStart = _getStartOfWeek((data['date'] as Timestamp).toDate());
      final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);

      final alreadyExists = grouped[weekKey]?.any((p) => p['id'] == doc.id) ?? false;
      if (!alreadyExists) {
        grouped.putIfAbsent(weekKey, () => []).add({
          'id': doc.id,
          'data': data,
        });
      }
    }

    setState(() {
      _groupedPlannings = grouped.entries.map((e) => {
        'week': e.key,
        'plannings': e.value,
      }).toList();
      _loading = false;
      _selectedPlannings.clear();
    });
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _supprimerPlanningsSelectionnes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer ${_selectedPlannings.length} planning(s) ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _colorScheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedPlannings) {
        await _firestore.collection('plannings').doc(id).delete();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: _colorScheme.onPrimary),
              const SizedBox(width: 8),
              Text('${_selectedPlannings.length} planning(s) supprimé(s) avec succès'),
            ],
          ),
          backgroundColor: _colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
          action: SnackBarAction(
            label: 'OK',
            textColor: _colorScheme.onPrimary,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      _chargerDonnees();
    }
  }

  String _getDayName(DateTime date) {
    const jours = [
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'
    ];
    return jours[date.weekday - 1];
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: _colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par date, tâche, contrôleur...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: _colorScheme.onSurfaceVariant),
              ),
              style: TextStyle(color: _colorScheme.onSurface),
              onChanged: (_) => setState(() {}),
            ),
          ),
          AnimatedSwitcher(
            duration: _animationDuration,
            child: _searchController.text.isNotEmpty
                ? IconButton(
              key: const ValueKey('clear'),
              icon: Icon(Icons.clear, color: _colorScheme.onSurfaceVariant),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;

    Color progressColor;
    if (progress == 0.0 && total > 0) {
      progressColor = Colors.grey; // rien fait
    } else if (progress == 1.0) {
      progressColor = Colors.green; // tout terminé
    } else {
      progressColor = Colors.orange; // partiellement ou en retard
    }

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: _colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            strokeWidth: 6,
          ),
          Text(
            '$completed/$total',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildWeeklyTable(List<Map<String, dynamic>> plannings) {
  // Tri par jour
  final ordered = [...plannings];
  ordered.sort((a, b) {
    final da = (a['data']['date'] as Timestamp).toDate();
    final db = (b['data']['date'] as Timestamp).toDate();
    return da.compareTo(db);
  });
  
  final horizontalController = ScrollController();

  return SizedBox(
    height: 320, // force un conteneur scrollable
    child: Scrollbar(
      thumbVisibility: true,
      controller: horizontalController,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: MaterialStatePropertyAll(_colorScheme.primary),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            dataRowHeight: 64,
            columns: const [
              DataColumn(label: Text("Jour")),
              DataColumn(label: Text("Date")),
              DataColumn(label: Text("Tâche")),
              DataColumn(label: Text("Entreprise")),
              DataColumn(label: Text("Sous-agence")),
              DataColumn(label: Text("Contrôleurs")),
              DataColumn(label: Text("Statut")),
            ],
            rows: ordered.map((item) {
              final data = item['data'];
              final date = (data['date'] as Timestamp).toDate();

              final List<dynamic> controleursIds =
                  data['controleurs'] ??
                  (data['controleurId'] != null ? [data['controleurId']] : []);

              final controleurNames = controleursIds
                  .map((id) => _controleurNames[id] ?? id.toString())
                  .join(', ');

              final effectue = data['effectue'] == true;
              final status = effectue ? 'Effectué' : 'Inachevée';

              return DataRow(
                selected: _selectedPlannings.contains(item['id']),
                onSelectChanged: (_) {
                  setState(() {
                    if (_selectedPlannings.contains(item['id'])) {
                      _selectedPlannings.remove(item['id']);
                    } else {
                      _selectedPlannings.add(item['id']);
                    }
                  });
                },
                cells: [
                  DataCell(Text(_getDayName(date))),
                  DataCell(Text(DateFormat('dd/MM/yyyy').format(date))),
                  DataCell(Text(data['tache'] ?? '--')),
                  DataCell(Text(data['entreprise'] ?? '--')),
                  DataCell(Text(data['sousAgence'] ?? '--')),
                  DataCell(Text(controleurNames)),
                  DataCell(
                    Text(
                      status,
                      style: TextStyle(
                        color: effectue ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}
  Widget _buildWeeklyPlanningCard(String week, List<Map<String, dynamic>> plannings) {
    final weekStart = DateTime.parse(week);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final completedCount = plannings.where((p) => p['data']['effectue'] == true).length;
    final totalCount = plannings.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    plannings.sort((a, b) {
      final dateA = (a['data']['date'] as Timestamp).toDate();
      final dateB = (b['data']['date'] as Timestamp).toDate();
      return dateA.weekday.compareTo(dateB.weekday);
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.all(20),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: SizedBox(
           width: 50,
           height: 50,
           child: CircleAvatar(
           backgroundColor: _colorScheme.primary.withOpacity(0.1),
           child: Icon(Icons.calendar_month, color: _colorScheme.primary, size: 24),
          ),
        ),

          title: Text(
            'Semaine du ${DateFormat('dd/MM/yyyy').format(weekStart)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _colorScheme.onSurface),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'au ${DateFormat('dd/MM/yyyy').format(weekEnd)}',
                style: TextStyle(fontSize: 14, color: _colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Chip(
                    label: Text('$totalCount tâche${totalCount > 1 ? 's' : ''}'),
                    backgroundColor: _colorScheme.surfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('$completedCount terminée${completedCount > 1 ? 's' : ''}'),
                    backgroundColor: _colorScheme.primaryContainer,
                    labelStyle: TextStyle(color: _colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ],
          ),
          trailing: _buildProgressIndicator(completedCount, totalCount),
          children: [
            _buildWeeklyTable(plannings),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _colorScheme.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200,
                height: 20,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: _colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            'Aucun planning trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos critères de recherche',
            style: TextStyle(color: _colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(List<Map<String, dynamic>> filtered) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return _buildWeeklyPlanningCard(entry['week'], entry['plannings']);
      },
    );
  }

  Widget _buildMobileLayout(List<Map<String, dynamic>> filtered) {
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return _buildWeeklyPlanningCard(entry['week'], entry['plannings']);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.toLowerCase();
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    // Recherche améliorée
    final filtered = _groupedPlannings.where((entry) {
      final plannings = entry['plannings'] as List<Map<String, dynamic>>;
      return plannings.any((p) {
        final data = p['data'] as Map<String, dynamic>;
        final date = (data['date'] as Timestamp).toDate();
        final dateStr = DateFormat('dd/MM/yyyy').format(date).toLowerCase();
        final task = (data['tache'] ?? '').toString().toLowerCase();
        final entreprise = (data['entreprise'] ?? '').toString().toLowerCase();
        final controleurId = data['controleurId'] ?? '';
        final controleurName = (_controleurNames[controleurId] ?? '').toLowerCase();

        return dateStr.contains(search) ||
            task.contains(search) ||
            entreprise.contains(search) ||
            controleurName.contains(search);
      });
    }).toList();

    return Scaffold(
      backgroundColor: _colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Consultation des plannings',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _colorScheme.primary,
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: 90,
        actions: [
          if (_selectedPlannings.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Supprimer la sélection',
              onPressed: _supprimerPlanningsSelectionnes,
            ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.refresh, size: 22, color: Colors.white),
            ),
            onPressed: _chargerDonnees,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: _selectedPlannings.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: _supprimerPlanningsSelectionnes,
        backgroundColor: _colorScheme.error,
        foregroundColor: _colorScheme.onError,
        icon: const Icon(Icons.delete),
        label: Text('Supprimer (${_selectedPlannings.length})'),
      )
          : null,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _fadeAnimation.value) * 20),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 20),
              if (_selectedPlannings.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _colorScheme.errorContainer.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _colorScheme.errorContainer),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedPlannings.length} planning(s) sélectionné(s) - Appuyez longuement pour désélectionner',
                          style: TextStyle(color: _colorScheme.onErrorContainer, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_selectedPlannings.isNotEmpty) const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? _buildLoadingSkeleton()
                    : filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                  onRefresh: _chargerDonnees,
                  color: _colorScheme.primary,
                  child: isLargeScreen
                      ? _buildDesktopLayout(filtered)
                      : _buildMobileLayout(filtered),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}