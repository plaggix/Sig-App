import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'consulter_planning_page.dart';
import 'package:collection/collection.dart';

class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage>
    with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _dateSemaineController = TextEditingController();

  // Map entrepriseId -> liste de titres de tâches
  Map<String, List<String>> _tachesParEntreprise = {};
  // Liste de sous-agences avec info entreprise
  List<Map<String, dynamic>> _sousAgences = [];
  // Liste des contrôleurs
  List<Map<String, dynamic>> _controleurs = [];
  // Planning temporaire pour la semaine : clé jour -> liste d'activités
  Map<String, List<Map<String, dynamic>>> _planningSemaine = {};
  // Historique/plannings déjà enregistrés (optionnel)
  List<DocumentSnapshot> _plannings = [];

  DateTime? _selectedStartOfWeek;
  bool _loading = true;
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

    _migrerUsersPourAjouterUid();
    _chargerDonnees().then((_) async {
      await _migrerPlanningsExistants();
      setState(() => _loading = false);
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    final entreprisesSnap = await _firestore.collection('entreprises').get();
    final userSnap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'contrôleur')
        .get();
    final planningsSnap = await _firestore
        .collection('plannings')
        .orderBy('date', descending: true)
        .get();

    final sousAgences = <Map<String, dynamic>>[];
    final Map<String, List<String>> tachesMap = {};

    for (var ent in entreprisesSnap.docs) {
      final sousSnap = await ent.reference.collection('sousAgences').get();
      for (var s in sousSnap.docs) {
        final sData = s.data() as Map<String, dynamic>;
        final entData = ent.data() as Map<String, dynamic>;
        sousAgences.add({
          'id': s.id,
          'nom': sData['nom'] ?? '',
          'entrepriseId': ent.id,
          'entrepriseNom': entData['nom'] ?? '',
          'sousAgenceActive': sData['actif'] ?? true,
          'entrepriseActive': entData['actif'] ?? true,
        });
      }

      final tacheSnap = await ent.reference.collection('taches').get();
      tachesMap[ent.id] = tacheSnap.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['titre']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    setState(() {
      _sousAgences = sousAgences;
      _tachesParEntreprise = tachesMap;
      _controleurs = userSnap.docs
          .map((doc) => {
                'uid': doc.id,
                'name':
                    (doc.data() as Map<String, dynamic>)['name']?.toString() ??
                        'Sans nom',
              })
          .toList();
      _plannings = planningsSnap.docs;
    });
  }

  Future<void> _migrerUsersPourAjouterUid() async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    for (final doc in users.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['uid'] == null || (data['uid'] as String?)?.isEmpty == true) {
        await doc.reference.update({'uid': doc.id});
      }
    }
  }

  Future<void> _migrerPlanningsExistants() async {
    final planningsSnap = await _firestore.collection('plannings').get();

    for (final doc in planningsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Si les champs n'existent pas, on les initialise
      final updateData = <String, dynamic>{};
      
      if (!data.containsKey('sousAgenceId')) {
        // On essaye de récupérer à partir du nom de sous-agence
        final sous = _sousAgences.firstWhere(
            (s) => s['nom'] == data['sousAgence'],
            orElse: () => {});
        updateData['sousAgenceId'] = sous['id'] ?? '';
        updateData['entrepriseId'] = sous['entrepriseId'] ?? '';
      }

      if (updateData.isNotEmpty) {
        await doc.reference.update(updateData);
      }
    }

    print('Migration des plannings terminée !');
  }

  void _ajouterPlanningJour(String jour) {
    _planningSemaine.putIfAbsent(jour, () => []);
    _planningSemaine[jour]!.add({
      'taches': <String>[],
      'entrepriseId': null,
      'sousAgence': null,
      'controleurs': <String>[],
      'note': '',
    });
    setState(() {});
  }

  void _supprimerPlanningJour(String jour, int index) {
    final deletedActivity = _planningSemaine[jour]?[index];
    _planningSemaine[jour]?.removeAt(index);
    if (_planningSemaine[jour]?.isEmpty ?? false) {
      _planningSemaine.remove(jour);
    }
    setState(() {});

    // Snackbar avec annulation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Activité supprimée'),
        backgroundColor: _colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius)),
        action: SnackBarAction(
          label: 'Annuler',
          textColor: Colors.white,
          onPressed: () {
            _planningSemaine.putIfAbsent(jour, () => []);
            _planningSemaine[jour]!.insert(index, deletedActivity!);
            setState(() {});
          },
        ),
      ),
    );
  }

  /// ENREGISTRER TOUTE LA SEMAINE D'UN COUP
  Future<void> _enregistrerPlanningSemaine() async {
    if (_selectedStartOfWeek == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez choisir la date de début de semaine'),
          backgroundColor: _colorScheme.errorContainer,
        ),
      );
      return;
    }

    final baseDate = _selectedStartOfWeek!;
    final jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final dateStr = DateFormat('yyyy-MM-dd').format(baseDate);

    // POUR CHAQUE JOUR
    final joursSnapshot = List<String>.from(_planningSemaine.keys);

    for (final jour in joursSnapshot) {
      final idx = jours.indexOf(jour);
      if (idx < 0) continue;

      final date = baseDate.add(Duration(days: idx));
      final activites = _planningSemaine[jour] ?? [];

      // POUR CHAQUE ACTIVITÉ
      for (var p in activites) {
        final List<String> taches = List<String>.from(p['taches'] ?? []);
        final List<String> controleurs =
            List<String>.from(p['controleurs'] ?? []);
        final sousAgence = p['sousAgence'];
        final entrepriseId = p['entrepriseId'];

        if (taches.isEmpty ||
            controleurs.isEmpty ||
            sousAgence == null ||
            entrepriseId == null) {
          continue;
        }

        // Récupérer le nom de l'entreprise
        final sousAgenceData = _sousAgences.firstWhere(
          (s) => s['nom'] == sousAgence,
          orElse: () => <String, dynamic>{},
        );
        final entrepriseNom = sousAgenceData['entrepriseNom'] ?? '';

        // 1️⃣ RÉCUPÉRER OU CRÉER LE RAPPORT
        final rapportQuery = await _firestore
            .collection('rapports')
            .where('sousAgenceId', isEqualTo: p['sousAgenceId'])
            .where('semaine', isEqualTo: dateStr)
            .limit(1)
            .get();

        String rapportId;

        if (rapportQuery.docs.isNotEmpty) {
          // Rapport existant
          rapportId = rapportQuery.docs.first.id;
        } else {
          // Création du rapport
          final rapportRef = await _firestore.collection('rapports').add({
            'entrepriseId': entrepriseId,
            'entrepriseNom': entrepriseNom,
            'sousAgenceId': p['sousAgenceId'],
            'sousAgenceNom': sousAgence,
            'semaine': dateStr,
            'createdAt': Timestamp.now(),
          });

          rapportId = rapportRef.id;
        }

        // POUR CHAQUE TÂCHE
        for (final tacheTitre in taches) {
          final taskDocId = const Uuid().v4(); 
          String taskInstanceId = const Uuid().v4();

          // 🔁 RECHERCHE D’UNE TÂCHE INACHEVÉE EXISTANTE
          final existingTaskQuery = await _firestore
            .collection('plannings')
            .where('tache', isEqualTo: tacheTitre)
            .where('sousAgenceId', isEqualTo: p['sousAgenceId'])
            .where('statut', isEqualTo: 'inachevee')
            .limit(1)
            .get();

            if (existingTaskQuery.docs.isNotEmpty) {
              final oldTask = existingTaskQuery.docs.first;

              // 1️⃣ marquer l’ancienne comme réaffectée
              await oldTask.reference.update({
                'statut': 'reaffectee',
              });

              // 2️⃣ reprendre la même identité logique
              taskInstanceId = oldTask['taskInstanceId'];
            }

         final activityMap = {
            'id': taskDocId,
            'taskInstanceId': taskInstanceId, // ⭐ AJOUT OBLIGATOIRE
            'tache': tacheTitre,
            'entrepriseId': entrepriseId,
            'entreprise': entrepriseNom,
            'sousAgence': sousAgence,
            'sousAgenceId': p['sousAgenceId'],
            'rapportId': rapportId,
            'assignedTo': controleurs, // logique actuelle conservée
            'note': p['note'] ?? '',
            'date': Timestamp.fromDate(date),
            'effectue': false,
            'statut': 'inachevee', // IMPORTANT
            'semaine': dateStr,
            'jour': jour,
          };

          // 🔵 Enregistrement global
          await _firestore.collection('plannings').doc(taskDocId).set(activityMap);

          // 🔵 Enregistrement pour CHAQUE contrôleur sélectionné
          for (final ctrlId in controleurs) {
            final userPlanningRef = _firestore
            .collection('user_plannings')
            .doc(ctrlId)
            .collection('plannings')
            .doc(taskInstanceId);

           await userPlanningRef.set({
              'id': taskDocId,
              'taskInstanceId': taskInstanceId, // AJOUT
              'rapportId': rapportId,
              'entrepriseId': entrepriseId,
              'sousAgenceId': activityMap['sousAgenceId'],
              'semaine': dateStr,
              'statut': 'inachevee',
              'effectue': false,
              'assignedTo': ctrlId,
              'jour': jour,
              'date': Timestamp.fromDate(date),
              'tache': tacheTitre,
            });
          }
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Planning de la semaine enregistré !'),
        backgroundColor: _colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius)),
      ),
    );

    _resetForm();
    await _chargerDonnees();
  }

  void _resetForm() {
    setState(() {
      _planningSemaine.clear();
      _selectedStartOfWeek = null;
      _dateSemaineController.clear();
    });
  }

  bool get _isFormValid {
  if (_selectedStartOfWeek == null) return false;

  for (final jourActivities in _planningSemaine.values) {
    for (final activity in jourActivities) {
      final controleurs =
          List<String>.from(activity['controleurs'] ?? []);

      if (controleurs.isNotEmpty &&
          activity['sousAgence'] != null &&
          activity['entrepriseId'] != null) {
        return true;
      }
    }
  }
  return false;
}

  Widget _buildPlanningFormCard(String jour, int index) {
    final p = _planningSemaine[jour]![index];

    final entrepriseId = p['entrepriseId'] as String?;
    final List<String> tachesEntreprise =
        entrepriseId != null ? (_tachesParEntreprise[entrepriseId] ?? []) : [];

    // APPLIQUER AUTO-ASSIGNATION DES TÂCHES
    if (entrepriseId != null &&
        !(ListEquality().equals(p['taches'], tachesEntreprise))) {
      p['taches'] = List<String>.from(tachesEntreprise);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER + DELETE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Activité ${index + 1}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _colorScheme.primary)),
                IconButton(
                  onPressed: () => _supprimerPlanningJour(jour, index),
                  icon: Icon(Icons.delete_outline, color: _colorScheme.error),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // SOUS-AGENCE
            DropdownButtonFormField<String>(
              value: p['sousAgence'] as String?,
              items: _sousAgences.map((s) {
                  final bool isDisabled =
                    s['entrepriseActive'] == false || s['sousAgenceActive'] == false;

                return DropdownMenuItem<String>(
                  value: isDisabled ? null : s['nom'],
                  enabled: !isDisabled,
                  child: Text(
                    "${s['nom']} (${s['entrepriseNom']})",
                    style: TextStyle(
                      color: isDisabled ? Colors.grey : null,
                      fontStyle: isDisabled ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                final sa = _sousAgences.firstWhere(
                  (s) => s['nom'] == value,
                  orElse: () => <String, dynamic>{},
                );

                if (sa['entrepriseActive'] == false || sa['sousAgenceActive'] == false) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Cette entreprise ou sous-agence est désactivée',
                      ),
                      backgroundColor: Colors.grey,
                    ),
                  );
                  return;
                }

                setState(() {
                  p['sousAgence'] = value;
                  if (sa.isNotEmpty) {
                    p['entrepriseId'] = sa['entrepriseId'];
                    p['sousAgenceId'] = sa['id'];
                    p['taches'] = List<String>.from(
                        _tachesParEntreprise[sa['entrepriseId']] ?? []);
                  } else {
                    p['entrepriseId'] = null;
                    p['taches'] = [];
                  }
                });
              },
              decoration: InputDecoration(
                labelText: 'Sous-agence *',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _colorScheme.surfaceVariant.withOpacity(0.3),
              ),
            ),

            const SizedBox(height: 12),

            // AFFICHAGE LISTE TÂCHES AUTO-ASSIGNÉES
            if (p['taches'] != null && (p['taches'] as List).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tâches assignées automatiquement :",
                        style: TextStyle(
                            color: _colorScheme.primary,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...p['taches']
                        .map<Widget>((t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.check,
                                      color: _colorScheme.primary, size: 16),
                                  const SizedBox(width: 8),
                                  Text(t),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // MULTI-SELECT CONTRÔLEURS
            GestureDetector(
              onTap: () => _openMultiControleurSelector(p),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _colorScheme.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Contrôleurs *"),
                    const SizedBox(height: 6),
                    if ((p['controleurs'] as List).isEmpty)
                      Text("Aucun sélectionné",
                          style:
                              TextStyle(color: _colorScheme.onSurfaceVariant))
                    else
                      Wrap(
                        spacing: 6,
                        children: (p['controleurs'] as List)
                            .map<Widget>((id) => Chip(
                                  label: Text(
                                    _controleurs.firstWhere(
                                        (c) => c['uid'] == id)['name'],
                                  ),
                                  backgroundColor:
                                      _colorScheme.primaryContainer,
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildNotesField(p),
          ],
        ),
      ),
    );
  }

  void _openMultiControleurSelector(Map<String, dynamic> planning) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateModal) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Sélectionner les contrôleurs",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: _controleurs.map((c) {
                        final isSelected = (planning['controleurs'] as List)
                            .contains(c['uid']);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(c['name']),
                          onChanged: (v) {
                            setStateModal(() {
                              if (v == true) {
                                (planning['controleurs'] as List<String>)
                                    .add(c['uid']);
                              } else {
                                planning['controleurs'].remove(c['uid']);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Valider"),
                  )
                ],
              ),
            );
          },
        );
      },
      isScrollControlled: true,
    );
  }

  Widget _buildNotesField(Map<String, dynamic> planning) {
    final hasNotes = (planning['note'] as String?)?.isNotEmpty == true;

    return ExpansionTile(
      initiallyExpanded: hasNotes,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 8),
      title: Row(
        children: [
          Icon(Icons.notes, size: 20, color: _colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Notes ${hasNotes ? '(remplie)' : ''}',
            style: TextStyle(
              color: hasNotes
                  ? _colorScheme.primary
                  : _colorScheme.onSurfaceVariant,
              fontWeight: hasNotes ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
      trailing: Icon(
        hasNotes ? Icons.edit_note : Icons.add_circle_outline,
        size: 20,
        color: _colorScheme.onSurfaceVariant,
      ),
      children: [
        TextFormField(
          initialValue: planning['note'] as String? ?? '',
          onChanged: (v) => planning['note'] = v,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ajouter des notes...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: _colorScheme.surfaceVariant.withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(String jour) {
    final plannings = _planningSemaine[jour] ?? [];
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
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
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.calendar_today,
                color: _colorScheme.primary, size: 20),
          ),
          title: Text(jour,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _colorScheme.onSurface)),
          subtitle: Text(
            '${plannings.length} activité${plannings.length != 1 ? 's' : ''}',
            style:
                TextStyle(fontSize: 14, color: _colorScheme.onSurfaceVariant),
          ),
          trailing: Badge(
            label: Text(plannings.length.toString()),
            backgroundColor: _colorScheme.primary,
            textColor: _colorScheme.onPrimary,
          ),
          onExpansionChanged: (expanded) {
            if (expanded && plannings.isEmpty) {
              _ajouterPlanningJour(jour);
            }
          },
          children: [
            if (plannings.isNotEmpty)
              AnimatedOpacity(
                opacity: 1.0,
                duration: _animationDuration,
                child: Column(
                  children: [
                    ...List.generate(plannings.length,
                        (i) => _buildPlanningFormCard(jour, i)),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => _ajouterPlanningJour(jour),
                      style: FilledButton.styleFrom(
                        backgroundColor: _colorScheme.primaryContainer,
                        foregroundColor: _colorScheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 20),
                          SizedBox(width: 8),
                          Text('Ajouter une activité'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.schedule,
                        size: 48,
                        color: _colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Aucune activité planifiée',
                      style: TextStyle(color: _colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
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
          Icon(Icons.calendar_month, color: _colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semaine de travail',
                  style: TextStyle(
                    fontSize: 14,
                    color: _colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2022),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final monday =
                          date.subtract(Duration(days: date.weekday - 1));
                      setState(() {
                        _selectedStartOfWeek = monday;
                        _dateSemaineController.text =
                            DateFormat('dd/MM/yyyy').format(monday);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _dateSemaineController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Sélectionner une date de début...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        suffixIcon: Icon(Icons.arrow_drop_down,
                            color: _colorScheme.onSurfaceVariant),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 6,
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
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 40,
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

  @override
  Widget build(BuildContext context) {
    final jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: _colorScheme.background,
      appBar: AppBar(
        title: const Text('Planning Hebdomadaire',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        backgroundColor: _colorScheme.primary,
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        toolbarHeight: 90,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.remove_red_eye,
                  size: 22, color: Colors.white),
            ),
            tooltip: 'Voir les plannings',
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ConsulterPlanning()));
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isFormValid
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.save,
                  size: 22,
                  color: _isFormValid
                      ? Colors.white
                      : Colors.white.withOpacity(0.5)),
            ),
            onPressed: _isFormValid ? _enregistrerPlanningSemaine : null,
            tooltip: 'Enregistrer toute la semaine',
          ),
        ],
      ),
      body: _loading
          ? _buildLoadingSkeleton()
          : AnimatedBuilder(
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
                    _buildDateSelector(),
                    const SizedBox(height: 20),

                    // En-tête planning
                    Row(
                      children: [
                        Icon(Icons.view_week,
                            color: _colorScheme.primary, size: 24),
                        const SizedBox(width: 12),
                        Text('Planning de la semaine',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _colorScheme.onSurface)),
                        const Spacer(),
                        if (_selectedStartOfWeek != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Semaine du ${DateFormat('dd/MM').format(_selectedStartOfWeek!)}',
                              style: TextStyle(
                                  color: _colorScheme.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grille responsive pour les jours
                    Expanded(
                      child: isLargeScreen
                          ? GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.5,
                              ),
                              itemCount: jours.length,
                              itemBuilder: (context, index) =>
                                  _buildDayCard(jours[index]),
                            )
                          : ListView.builder(
                              itemCount: jours.length,
                              itemBuilder: (context, index) =>
                                  _buildDayCard(jours[index]),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
