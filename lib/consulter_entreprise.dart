import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

class GererEntreprisesTachesPage extends StatefulWidget {
  const GererEntreprisesTachesPage({super.key});

  @override
  State<GererEntreprisesTachesPage> createState() => _GererEntreprisesTachesPageState();
}

class _GererEntreprisesTachesPageState extends State<GererEntreprisesTachesPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Controllers général
  final TextEditingController _searchController = TextEditingController();

  // Form controllers (entreprise)
  final _formKeyEntreprise = GlobalKey<FormState>();
  final TextEditingController _nomEntrepriseController = TextEditingController();
  final TextEditingController _directeurEntrepriseController = TextEditingController();

  // Form controllers (sous-agence)
  final TextEditingController _nomSousAgenceController = TextEditingController();
  final TextEditingController _villeSousAgenceController = TextEditingController();

  // Form controllers (tâche globale)
  final TextEditingController _titreTacheController = TextEditingController();
  final TextEditingController _descTacheController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nomEntrepriseController.dispose();
    _directeurEntrepriseController.dispose();
    _nomSousAgenceController.dispose();
    _villeSousAgenceController.dispose();
    _titreTacheController.dispose();
    _descTacheController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // -------------------- Helper UI --------------------
  void _showSnack(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _confirmDialog({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // -------------------- Firestore helpers --------------------

  // Crée une tâche globale et retourne son id
  Future<String?> _createGlobalTache({required String titre, String? description}) async {
    try {
      final docRef = await _firestore.collection('taches').add({
        'titre': titre.trim(),
        'description': description?.trim() ?? '',
        'dateCreation': Timestamp.now(),
      });
      return docRef.id;
    } catch (e) {
      _showSnack('Erreur création tâche : ${e.toString()}', success: false);
      return null;
    }
  }

  // Supprime une tâche globale et la retire de toutes les entreprises et sous-agences
  Future<void> _deleteGlobalTache(String tacheId) async {
    final confirm = await _confirmDialog(title: 'Supprimer la tâche', content: 'Cette suppression supprimera la tâche globalement (pour toutes les entreprises).');
    if (confirm != true) return;
    try {
      // Supprimer la tâche globale
      await _firestore.collection('taches').doc(tacheId).delete();

      // Retirer des entreprises (update in batches)
      final entreprises = await _firestore.collection('entreprises').get();
      final batch = _firestore.batch();
      for (final e in entreprises.docs) {
        final ref = e.reference;
        batch.update(ref, {'taches': FieldValue.arrayRemove([tacheId])});
        // Retirer des sous-agences
        final sousAgencesSnap = await ref.collection('sousAgences').get();
        for (final s in sousAgencesSnap.docs) {
          batch.update(s.reference, {'taches': FieldValue.arrayRemove([tacheId])});
        }
      }
      await batch.commit();
      _showSnack('Tâche supprimée globalement.', success: true);
    } catch (e) {
      _showSnack('Erreur suppression tâche: ${e.toString()}', success: false);
    }
  }

  // Crée une entreprise avec la liste de taches sélectionnées (liste d'IDs).
  Future<void> _createEntreprise({required String nom, required String directeur, required List<String> tachesIds}) async {
    try {
      final docRef = await _firestore.collection('entreprises').add({
        'nom': nom.trim(),
        'directeur': directeur.trim(),
        'dateCreation': Timestamp.now(),
        'taches': tachesIds,
        'isActive': true,
      });

      // Créer automatiquement la collection sousAgences vide ; mais si tu veux initialiser, on peut
      // Hériter taches dans les sous-agences (si on crée des sous-agences plus tard on les initialisera)
      // On met à jour les sous-agences existantes (s'il y en a) pour refléter les taches par défaut
      await _syncTachesToSousAgences(docRef.id, tachesIds);

      _showSnack('Entreprise crée avec succès !', success: true);
    } catch (e) {
      _showSnack('Erreur création entreprise : ${e.toString()}', success: false);
    }
  }

  // Modifier entreprise (nom/directeur + éventuellement update de taches)
  Future<void> _updateEntreprise({required String entrepriseId, required String nom, required String directeur, List<String>? taches}) async {
    try {
      final data = {'nom': nom.trim(), 'directeur': directeur.trim()};
      if (taches != null) {
      await FirebaseFirestore.instance
      .collection('entreprises')
      .doc(entrepriseId)
      .update({'taches': taches});
}

      await _firestore.collection('entreprises').doc(entrepriseId).update(data);

      if (taches != null) {
        // Propager aux sous-agences pour que l'appartenance soit la même
        await _syncTachesToSousAgences(entrepriseId, taches);
      }

      _showSnack('Entreprise modifiée !', success: true);
    } catch (e) {
      _showSnack('Erreur modification : ${e.toString()}', success: false);
    }
  }

  // Supprimer entreprise (et toutes ses sous-agences)
  Future<void> _deleteEntreprise(String entrepriseId) async {
    final confirm = await _confirmDialog(title: 'Supprimer l\'entreprise', content: 'Voulez-vous vraiment supprimer cette entreprise et toutes ses sous-agences ?');
    if (confirm != true) return;
    try {
      final entrepriseRef = _firestore.collection('entreprises').doc(entrepriseId);

      // Supprime sous-agences
      final sousAgencesSnap = await entrepriseRef.collection('sousAgences').get();
      final batch = _firestore.batch();
      for (final s in sousAgencesSnap.docs) batch.delete(s.reference);

      // Supprime entreprise
      batch.delete(entrepriseRef);
      await batch.commit();

      _showSnack('Entreprise supprimée.', success: true);
    } catch (e) {
      _showSnack('Erreur suppression entreprise: ${e.toString()}', success: false);
    }
  }

  Future<void> _createMissingRapportsForExistingSousAgences() async {
  final user = _auth.currentUser;
  if (user == null) return;

  final entreprisesSnap = await _firestore.collection('entreprises').get();

  for (final e in entreprisesSnap.docs) {
    final entrepriseId = e.id;
    final entrepriseNom = e['nom'] ?? '';

    final sousSnap = await e.reference.collection('sousAgences').get();

    for (final s in sousSnap.docs) {
      final sousAgenceId = s.id;
      final sousAgenceNom = s['nom'] ?? '';

      final existingRapport = await _firestore
          .collection('rapports')
          .where('sousAgenceId', isEqualTo: sousAgenceId)
          .limit(1)
          .get();

      if (existingRapport.docs.isEmpty) {
        await _firestore.collection('rapports').add({
          'ownerUid': user.uid,
          'entrepriseId': entrepriseId,
          'entrepriseNom': entrepriseNom,
          'sousAgenceId': sousAgenceId,
          'sousAgenceNom': sousAgenceNom,
          'createdAt': Timestamp.now(),
          'statut': 'en_cours',
        });
      }
    }
  }
}

  // Ajouter sous-agence (hérite des tâches actuelles de l'entreprise)
Future<void> _createSousAgence(
  String entrepriseId, {
  required String nom,
  String? ville,
}) async {
  try {
    final entrepriseDoc =
        await _firestore.collection('entreprises').doc(entrepriseId).get();

    final taches = List<String>.from(entrepriseDoc.data()?['taches'] ?? []);

    final sousAgenceRef = await _firestore
        .collection('entreprises')
        .doc(entrepriseId)
        .collection('sousAgences')
        .add({
      'nom': nom.trim(),
      'ville': ville?.trim() ?? '',
      'dateCreation': Timestamp.now(),
      'taches': taches,
      'isActive': true,
    });

    // 🔥 création automatique du rapport
    await _createRapportForSousAgence(
      entrepriseId: entrepriseId,
      entrepriseNom: entrepriseDoc['nom'] ?? '',
      sousAgenceId: sousAgenceRef.id,
      sousAgenceNom: nom.trim(),
    );

    _showSnack('Sous-agence ajoutée.', success: true);
  } catch (e) {
    _showSnack('Erreur ajout sous-agence: ${e.toString()}', success: false);
  }
}

Future<void> _toggleEntrepriseActive(
  String entrepriseId,
  bool newValue,
) async {
  try {
    final entrepriseRef =
        _firestore.collection('entreprises').doc(entrepriseId);

    final sousAgencesSnap =
        await entrepriseRef.collection('sousAgences').get();

    final batch = _firestore.batch();

    // entreprise
    batch.update(entrepriseRef, {'isActive': newValue});

    // sous-agences
    for (final s in sousAgencesSnap.docs) {
      batch.update(s.reference, {'isActive': newValue});
    }

    await batch.commit();

    _showSnack(
      newValue
          ? 'Entreprise activée'
          : 'Entreprise désactivée',
      success: true,
    );
  } catch (e) {
    _showSnack(
      'Erreur changement état : ${e.toString()}',
      success: false,
    );
  }
}


  Future<void> _createRapportForSousAgence({
  required String entrepriseId,
  required String entrepriseNom,
  required String sousAgenceId,
  required String sousAgenceNom,
}) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final rapportRef = await _firestore.collection('rapports').add({
  'entrepriseId': entrepriseId,
  'entrepriseNom': entrepriseNom,
  'sousAgenceId': sousAgenceId,
  'sousAgenceNom': sousAgenceNom,
  'createdAt': Timestamp.now(),
  'statut': 'en_cours',
  'validations': {},
  'observations': {},
});

// ID DU RAPPORT
final rapportId = rapportRef.id;

}

  // Edit sous-agence
  Future<void> _updateSousAgence(String entrepriseId, String sousAgenceId, {required String nom, String? ville}) async {
    try {
      await _firestore.collection('entreprises').doc(entrepriseId).collection('sousAgences').doc(sousAgenceId).update({
        'nom': nom.trim(),
        'ville': ville?.trim() ?? '',
      });
      _showSnack('Sous-agence modifiée.', success: true);
    } catch (e) {
      _showSnack('Erreur modification sous-agence: ${e.toString()}', success: false);
    }
  }

  // Supprimer sous-agence
  Future<void> _deleteSousAgence(String entrepriseId, String sousAgenceId) async {
    final confirm = await _confirmDialog(title: 'Supprimer la sous-agence', content: 'Voulez-vous vraiment supprimer cette sous-agence ?');
    if (confirm != true) return;
    try {
      await _firestore.collection('entreprises').doc(entrepriseId).collection('sousAgences').doc(sousAgenceId).delete();
      _showSnack('Sous-agence supprimée.', success: true);
    } catch (e) {
      _showSnack('Erreur suppression sous-agence: ${e.toString()}', success: false);
    }
  }

  // Supprimer une tâche pour une entreprise (local remove only)
  Future<void> _removeTacheFromEntreprise(String entrepriseId, String tacheId) async {
    try {
      final entrepriseRef = _firestore.collection('entreprises').doc(entrepriseId);
      await entrepriseRef.update({'taches': FieldValue.arrayRemove([tacheId])});
      // Retirer aussi des sous-agences
      final sousAgencesSnap = await entrepriseRef.collection('sousAgences').get();
      final batch = _firestore.batch();
      for (final s in sousAgencesSnap.docs) {
        batch.update(s.reference, {'taches': FieldValue.arrayRemove([tacheId])});
      }
      await batch.commit();
      _showSnack('Tâche retirée de l\'entreprise (local).', success: true);
    } catch (e) {
      _showSnack('Erreur suppression locale tâche: ${e.toString()}', success: false);
    }
  }

  // Ajoute une tâche (id) à une entreprise (et aux sous-agences)
  Future<void> _addTacheToEntreprise(String entrepriseId, String tacheId) async {
    try {
      final entrepriseRef = _firestore.collection('entreprises').doc(entrepriseId);
      await entrepriseRef.update({'taches': FieldValue.arrayUnion([tacheId])});
      await _syncTachesToSousAgencesFromEntrepriseRef(entrepriseRef);
      _showSnack('Tâche ajoutée à l\'entreprise.', success: true);
    } catch (e) {
      _showSnack('Erreur ajout tâche à l\'entreprise: ${e.toString()}', success: false);
    }
  }

  // Sync helper : écrase les taches des sous-agences pour correspondre à la liste fournie
  Future<void> _syncTachesToSousAgences(String entrepriseId, List<String> taches) async {
    try {
      final sousAgencesSnap = await _firestore.collection('entreprises').doc(entrepriseId).collection('sousAgences').get();
      final batch = _firestore.batch();
      for (final s in sousAgencesSnap.docs) {
        batch.update(s.reference, {'taches': taches});
      }
      await batch.commit();
    } catch (e) {
      // ignore ou log
    }
  }

  // Variante si on a déjà le ref
  Future<void> _syncTachesToSousAgencesFromEntrepriseRef(DocumentReference entrepriseRef) async {
    try {
      final entrepriseDoc = await entrepriseRef.get();
      final data = entrepriseDoc.data() as Map<String, dynamic>;
      final taches = List<String>.from(data['taches'] ?? []);
      final sousAgencesSnap = await entrepriseRef.collection('sousAgences').get();
      final batch = _firestore.batch();
      for (final s in sousAgencesSnap.docs) {
        batch.update(s.reference, {'taches': taches});
      }
      await batch.commit();
    } catch (e) {
      // ignore
    }
  }

  // -------------------- UI - DIALOGS --------------------

  // Dialog : créer/éditer tâche globale
  Future<void> _openCreateEditTacheDialog({String? tacheId, String initialTitre = '', String initialDesc = ''}) async {
    _titreTacheController.text = initialTitre;
    _descTacheController.text = initialDesc;

    final isEdit = tacheId != null;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Modifier tâche' : 'Nouvelle tâche'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titreTacheController, decoration: const InputDecoration(labelText: 'Titre *')),
            const SizedBox(height: 8),
            TextField(controller: _descTacheController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final titre = _titreTacheController.text.trim();
              if (titre.isEmpty) {
                _showSnack('Titre requis.', success: false);
                return;
              }
              if (isEdit) {
                await _firestore.collection('taches').doc(tacheId).update({
                  'titre': titre,
                  'description': _descTacheController.text.trim(),
                });
                Navigator.pop(ctx, true);
                _showSnack('Tâche modifiée.', success: true);
              } else {
                await _createGlobalTache(titre: titre, description: _descTacheController.text.trim());
                Navigator.pop(ctx, true);
              }
            },
            child: Text(isEdit ? 'MODIFIER' : 'ENREGISTRER'),
          ),
        ],
      ),
    );

    if (result == true) {
      _titreTacheController.clear();
      _descTacheController.clear();
    }
  }

  // Dialog : création/édition d'entreprise (avec checklist des taches)
  // Si entrepriseId != null => édition (récupérer ses taches)
  Future<void> _openCreateEditEntrepriseDialog({String? entrepriseId, String? initialNom, String? initialDirecteur}) async {
    final isEdit = entrepriseId != null;
    _nomEntrepriseController.text = initialNom ?? '';
    _directeurEntrepriseController.text = initialDirecteur ?? '';

    // Load global tasks
    final tasksSnap = await _firestore
    .collection('taches')
    .orderBy('dateCreation', descending: true)
    .get();

    // tasks est mutable (sans 'final')
    List<QueryDocumentSnapshot<Map<String, dynamic>>> tasks = tasksSnap.docs;


    // For editing: get entreprise's current taches set
    final Set<String> selectedIds = {};
    if (isEdit) {
      final eDoc = await _firestore.collection('entreprises').doc(entrepriseId).get();
      final list = List<String>.from(eDoc.data()?['taches'] ?? []);
      selectedIds.addAll(list);
    } else {
      // création par défaut : toutes cochées
      for (var d in tasks) selectedIds.add(d.id);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? 'Modifier entreprise' : 'Nouvelle entreprise'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Form(
                        key: _formKeyEntreprise,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nomEntrepriseController,
                              decoration: const InputDecoration(labelText: 'Nom *'),
                              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _directeurEntrepriseController,
                              decoration: const InputDecoration(labelText: 'Dirigeant *'),
                              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tâches disponibles', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton.icon(
                            onPressed: () async {
                              // Créer une nouvelle tâche directement depuis le formulaire
                              final created = await showDialog<bool>(
                                context: context,
                                builder: (ctx2) => AlertDialog(
                                  title: const Text('Créer tâche'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(controller: _titreTacheController, decoration: const InputDecoration(labelText: 'Titre *')),
                                      const SizedBox(height: 8),
                                      TextField(controller: _descTacheController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Annuler')),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final titre = _titreTacheController.text.trim();
                                        if (titre.isEmpty) {
                                          // ignore
                                          return;
                                        }
                                        final newId = await _createGlobalTache(titre: titre, description: _descTacheController.text.trim());
                                        if (newId != null) {
                                          // 2) Récupère la liste à jour DES TÂCHES depuis Firestore (await *avant* setStateDialog)
                                         final updatedSnap = await FirebaseFirestore.instance
                                          .collection('taches')
                                          .orderBy('dateCreation', descending: true)
                                          .get(); // QuerySnapshot<Map<String,dynamic>>

                                         // 3) Puis mets à jour l'UI dans la closure setStateDialog (synchrone)
                                         setStateDialog(() {
                                         // Remplace la liste locale 'tasks' par la liste à jour :
                                          tasks = updatedSnap.docs
                                            .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
                                           // Coche automatiquement la nouvelle tâche
                                           selectedIds.add(newId);
  });
                                          _titreTacheController.clear();
                                          _descTacheController.clear();
                                        }
                                        Navigator.pop(ctx2, true);
                                      },
                                      child: const Text('Créer'),
                                    ),
                                  ],
                                ),
                              );
                              // pour montrer la tâche fraîchement créée, on rafraîchit la liste locale
                              if (created == true) {
                                // reload tasks list
                                final updated = await _firestore.collection('taches').orderBy('dateCreation', descending: true).get();
                                // remplacer content (setStateDialog)
                                setStateDialog(() {
                                  // remplacer tasks list
                                  // ignore: unnecessary_statements
                                  // tasks variable non mutable en closure, workaround: use parent variable via a local copy
                                });
                                // pour simplicité : on ne recrée pas la variable tasks (ceci est un détail UI mineur),
                                // mais la nouvelle tâche a bien été créée et cochée dans selectedIds.
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nouvelle tâche'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Checklist - on affiche la liste des tâches globales
                      if (tasks.isEmpty)
                        const Text('Aucune tâche globale disponible.')
                      else
                        Column(
                          children: tasks.map((d) {
                            final titre = (d.data() as Map<String, dynamic>)['titre'] ?? '';
                            final id = d.id;
                            return CheckboxListTile(
                              value: selectedIds.contains(id),
                              title: Text(titre),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (v) => setStateDialog(() {
                                if (v == true) {
                                  selectedIds.add(id);
                                } else {
                                  selectedIds.remove(id);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                ElevatedButton(
                  onPressed: () async {
                    if (!_formKeyEntreprise.currentState!.validate()) return;
                    final nom = _nomEntrepriseController.text.trim();
                    final directeur = _directeurEntrepriseController.text.trim();
                    final selectedList = selectedIds.toList();
                    if (isEdit) {
                      await _updateEntreprise(entrepriseId: entrepriseId!, nom: nom, directeur: directeur, taches: selectedList);
                    } else {
                      await _createEntreprise(nom: nom, directeur: directeur, tachesIds: selectedList);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'MODIFIER' : 'ENREGISTRER'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dialog : gérer les taches assignées à une entreprise (checkboxes, avec possibilité de retirer localement ou ajouter une tâche globale)
  Future<void> _openManageEntrepriseTachesDialog(String entrepriseId) async {
    final entrepriseDoc = await _firestore.collection('entreprises').doc(entrepriseId).get();
    final currentTaches = List<String>.from(entrepriseDoc.data()?['taches'] ?? []);
    final tasksSnap = await _firestore.collection('taches').orderBy('dateCreation', descending: true).get();
    final tasks = tasksSnap.docs;

    final selected = Set<String>.from(currentTaches);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Gérer tâches de l\'entreprise'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (tasks.isEmpty) const Text('Aucune tâche globale disponible.') else
                      Column(
                        children: tasks.map((d) {
                          final id = d.id;
                          final titre = (d.data() as Map<String, dynamic>)['titre'] ?? '';
                          return CheckboxListTile(
                            value: selected.contains(id),
                            title: Text(titre),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (v) => setStateDialog(() {
                              if (v == true) selected.add(id);
                              else selected.remove(id);
                            }),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        // create a new task global and add it to selected
                        final res = await showDialog<bool>(
                          context: context,
                          builder: (ctx2) => AlertDialog(
                            title: const Text('Créer tâche'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(controller: _titreTacheController, decoration: const InputDecoration(labelText: 'Titre *')),
                                const SizedBox(height: 8),
                                TextField(controller: _descTacheController, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Annuler')),
                              ElevatedButton(
                                onPressed: () async {
                                  final titre = _titreTacheController.text.trim();
                                  if (titre.isEmpty) return;
                                  final newId = await _createGlobalTache(titre: titre, description: _descTacheController.text.trim());
                                  if (newId != null) {
                                    setStateDialog(() {
                                      selected.add(newId);
                                    });
                                  }
                                  _titreTacheController.clear();
                                  _descTacheController.clear();
                                  Navigator.pop(ctx2, true);
                                },
                                child: const Text('Créer'),
                              ),
                            ],
                          ),
                        );
                        if (res == true) {
                          // nothing more; selected already updated
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Créer et ajouter une tâche'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  // Mettre à jour la liste 'taches' de l'entreprise et propager aux sous-agences
                  await _updateEntreprise(entrepriseId: entrepriseId, nom: entrepriseDoc['nom'] ?? '', directeur: entrepriseDoc['directeur'] ?? '', taches: selected.toList());
                  Navigator.pop(ctx);
                },
                child: const Text('ENREGISTRER'),
              ),
            ],
          );
        });
      },
    );
  }

  // -------------------- WIDGETS --------------------

  Widget _buildEntrepriseCard(QueryDocumentSnapshot entrepriseDoc) {
    final nom = entrepriseDoc['nom'] ?? '';
    final directeur = entrepriseDoc['directeur'] ?? '';
    final date = (entrepriseDoc['dateCreation'] as Timestamp).toDate();
    final data = entrepriseDoc.data() as Map<String, dynamic>;
    final isActive = data.containsKey('isActive') ? data['isActive'] as bool : true;



    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Text(
              nom,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isActive ? null : Colors.grey,
              ),
            ),
            if (!isActive)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                '(désactivée)',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Dirigeant: $directeur • ${DateFormat('dd/MM/yyyy').format(date)}',
          style: TextStyle(color: isActive ? null : Colors.grey),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final id = entrepriseDoc.id;
            if (v == 'edit') {
              await _openCreateEditEntrepriseDialog(entrepriseId: id, initialNom: nom, initialDirecteur: directeur);
            } else if (v == 'delete') {
              await _deleteEntreprise(id);
            } else if (v == 'toggleActive') {
              final confirm = await _confirmDialog(
                title: isActive ? 'Désactiver entreprise' : 'Activer entreprise',
                content: isActive
                ? 'Cette action désactivera l’entreprise et toutes ses sous-agences.'
                : 'Cette action réactivera l’entreprise et toutes ses sous-agences.',
              );

            if (confirm == true) {
              await _toggleEntrepriseActive(entrepriseDoc.id, !isActive);
            }
          }else if (v == 'addSousAgence') {
              // ouvrir bottom sheet pour ajouter sous-agence
              _nomSousAgenceController.clear();
              _villeSousAgenceController.clear();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('Ajouter sous-agence', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      TextField(controller: _nomSousAgenceController, decoration: const InputDecoration(labelText: 'Nom *')),
                      const SizedBox(height: 8),
                      TextField(controller: _villeSousAgenceController, decoration: const InputDecoration(labelText: 'Ville (optionnel)')),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final nomS = _nomSousAgenceController.text.trim();
                          if (nomS.isEmpty) {
                            _showSnack('Nom requis', success: false);
                            return;
                          }
                          Navigator.pop(ctx);
                          await _createSousAgence(id, nom: nomS, ville: _villeSousAgenceController.text.trim());
                        },
                        child: const Text('ENREGISTRER'),
                      ),
                    ]),
                  ),
                ),
              );
            } else if (v == 'manageTaches') {
              await _openManageEntrepriseTachesDialog(entrepriseDoc.id);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'addSousAgence', child: ListTile(leading: Icon(Icons.add_location_alt_outlined), title: Text('Ajouter sous-agence'))),
            const PopupMenuItem(value: 'manageTaches', child: ListTile(leading: Icon(Iconsax.task_square), title: Text('Gérer tâches'))),
             PopupMenuItem(
                value: 'toggleActive',
                child: ListTile(
                  leading: Icon(
                    isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    color: isActive ? Colors.orange : Colors.green,
                  ),
                  title: Text(isActive ? 'Désactiver' : 'Activer'),
                ),
              ),
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Modifier'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Supprimer', style: TextStyle(color: Colors.red)))),
          ],
        ),
        children: [
          // list sous-agences
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('entreprises').doc(entrepriseDoc.id).collection('sousAgences').orderBy('dateCreation', descending: true).snapshots(),
            builder: (context, snapSous) {
              final sous = snapSous.data?.docs ?? [];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sous-agences', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
                    const SizedBox(height: 8),
                    if (sous.isEmpty)
                      Text('Aucune sous-agence', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))
                    else
                      ...sous.map((s) {
                        final nomS = s['nom'] ?? '';
                        final ville = s['ville'] ?? '';
                        final dateS = (s['dateCreation'] as Timestamp).toDate();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(nomS),
                          subtitle: Text('${ville.isNotEmpty ? 'Ville: $ville • ' : ''}Créée le ${DateFormat('dd/MM/yyyy').format(dateS)}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () {
                                _nomSousAgenceController.text = nomS;
                                _villeSousAgenceController.text = ville;
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (ctx2) => Padding(
                                    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        Text('Modifier sous-agence', style: TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 12),
                                        TextField(controller: _nomSousAgenceController, decoration: const InputDecoration(labelText: 'Nom *')),
                                        const SizedBox(height: 8),
                                        TextField(controller: _villeSousAgenceController, decoration: const InputDecoration(labelText: 'Ville (optionnel)')),
                                        const SizedBox(height: 12),
                                        ElevatedButton(
                                          onPressed: () async {
                                            final nomNew = _nomSousAgenceController.text.trim();
                                            if (nomNew.isEmpty) {
                                              _showSnack('Nom requis', success: false);
                                              return;
                                            }
                                            Navigator.pop(ctx2);
                                            await _updateSousAgence(entrepriseDoc.id, s.id, nom: nomNew, ville: _villeSousAgenceController.text.trim());
                                          },
                                          child: const Text('MODIFIER'),
                                        ),
                                      ]),
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteSousAgence(entrepriseDoc.id, s.id),
                            ),
                          ]),
                        );
                      }).toList(),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEntreprisesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('entreprises').orderBy('dateCreation', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Iconsax.buildings, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
              const SizedBox(height: 12),
              const Text('Aucune entreprise enregistrée', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _openCreateEditEntrepriseDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une entreprise'),
              ),
            ]),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 300));
            return;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildEntrepriseCard(docs[index]),
          ),
        );
      },
    );
  }

  // -------------------- Tâches Tab --------------------
  Widget _buildTachesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('taches').orderBy('dateCreation', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data?.docs ?? [];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                const Expanded(child: Text('Tâches globales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                ElevatedButton.icon(onPressed: () => _openCreateEditTacheDialog(), icon: const Icon(Icons.add), label: const Text('Nouvelle')),
              ]),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Expanded(child: Center(child: Text('Aucune tâche enregistrée', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)))))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final titre = (d.data() as Map<String, dynamic>)['titre'] ?? '';
                      final desc = (d.data() as Map<String, dynamic>)['description'] ?? '';
                      final date = ((d.data() as Map<String, dynamic>)['dateCreation'] as Timestamp).toDate();
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if ((desc as String).isNotEmpty) Text(desc),
                            Text('Créée le ${DateFormat('dd/MM/yyyy').format(date)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                          ]),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                await _openCreateEditTacheDialog(tacheId: d.id, initialTitre: titre, initialDesc: desc);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteGlobalTache(d.id),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // -------------------- BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Gestion Entreprises & Tâches', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Iconsax.buildings_2), text: 'Entreprises'),
            Tab(icon: Icon(Iconsax.task_square), text: 'Tâches'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Synchroniser rapports (1 fois)',
            onPressed: () async {
             await _createMissingRapportsForExistingSousAgences();
             _showSnack('Rapports synchronisés avec succès');
            },
          ),
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openCreateEditEntrepriseDialog(),
              tooltip: 'Ajouter entreprise',
            )
          else
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openCreateEditTacheDialog(),
              tooltip: 'Nouvelle tâche globale',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEntreprisesTab(),
          _buildTachesTab(),
        ],
      ),
    );
  }
}
