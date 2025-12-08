import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class GererEntreprisesPage extends StatefulWidget {
  const GererEntreprisesPage({super.key});

  @override
  State<GererEntreprisesPage> createState() => _GererEntreprisesPageState();
}

class _GererEntreprisesPageState extends State<GererEntreprisesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _directeurController = TextEditingController();
  final TextEditingController _sousAgenceNomController = TextEditingController();
  final TextEditingController _sousAgenceVilleController = TextEditingController();
  final TextEditingController _tacheTitreController = TextEditingController();
  final TextEditingController _tacheDescController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<DocumentSnapshot> _filteredEntreprises = [];
  List<DocumentSnapshot> _allEntreprises = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredEntreprises = _allEntreprises;
      });
    } else {
      setState(() {
        _filteredEntreprises = _allEntreprises.where((entreprise) {
          final data = entreprise.data() as Map<String, dynamic>;
          final nom = data['nom']?.toString().toLowerCase() ?? '';
          final directeur = data['directeur']?.toString().toLowerCase() ?? '';
          return nom.contains(query) || directeur.contains(query);
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _directeurController.dispose();
    _sousAgenceNomController.dispose();
    _sousAgenceVilleController.dispose();
    _tacheTitreController.dispose();
    _tacheDescController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------------- ENTREPRISES ----------------
  Future<void> _ajouterEntreprise() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _firestore.collection('entreprises').add({
          'nom': _nomController.text.trim(),
          'directeur': _directeurController.text.trim(),
          'dateCreation': Timestamp.now(),
        });

        Navigator.pop(context);
        _nomController.clear();
        _directeurController.clear();

        _showSnack('Entreprise ajoutée avec succès !', success: true);
      } catch (e) {
        _showSnack('Erreur : ${e.toString()}', success: false);
      }
    }
  }

  void _modifierEntreprise(String entrepriseId, String nom, String directeur) {
    _nomController.text = nom;
    _directeurController.text = directeur;

    _ouvrirFormulaireAjout(isEdition: true, entrepriseId: entrepriseId);
  }

  Future<void> _supprimerEntreprise(String entrepriseId) async {
    try {
      await _firestore.collection('entreprises').doc(entrepriseId).delete();
      _showSnack('Entreprise supprimée !', success: true);
    } catch (e) {
      _showSnack('Erreur : ${e.toString()}', success: false);
    }
  }

  // ---------------- SOUS-AGENCES ----------------
  Future<void> _ajouterSousAgence(String entrepriseId) async {
    if (_sousAgenceNomController.text.trim().isEmpty) return;
    try {
      await _firestore
          .collection('entreprises')
          .doc(entrepriseId)
          .collection('sousAgences')
          .add({
        'nom': _sousAgenceNomController.text.trim(),
        'ville': _sousAgenceVilleController.text.trim(),
        'dateCreation': Timestamp.now(),
      });
      Navigator.pop(context);
      _sousAgenceNomController.clear();
      _sousAgenceVilleController.clear();
      _showSnack('Sous-agence ajoutée avec succès !', success: true);
    } catch (e) {
      _showSnack('Erreur : ${e.toString()}', success: false);
    }
  }

  void _modifierSousAgence(String entrepriseId, String sousAgenceId, String nom, String ville) {
    _sousAgenceNomController.text = nom;
    _sousAgenceVilleController.text = ville;

    _ouvrirFormulaireAjoutSousAgence(
      entrepriseId,
      isEdition: true,
      sousAgenceId: sousAgenceId,
    );
  }

  Future<void> _supprimerSousAgence(String entrepriseId, String sousAgenceId) async {
    try {
      await _firestore
          .collection('entreprises')
          .doc(entrepriseId)
          .collection('sousAgences')
          .doc(sousAgenceId)
          .delete();
      _showSnack('Sous-agence supprimée !', success: true);
    } catch (e) {
      _showSnack('Erreur : ${e.toString()}', success: false);
    }
  }

  // ---------------- TACHES ----------------
  Future<void> _ajouterTache(String entrepriseId) async {
    if (_tacheTitreController.text.trim().isEmpty) return;
    try {
      await _firestore
          .collection('entreprises')
          .doc(entrepriseId)
          .collection('taches')
          .add({
        'titre': _tacheTitreController.text.trim(),
        'description': _tacheDescController.text.trim(),
        'dateCreation': Timestamp.now(),
      });
      Navigator.pop(context);
      _tacheTitreController.clear();
      _tacheDescController.clear();
      _showSnack('Tâche ajoutée avec succès !', success: true);
    } catch (e) {
      _showSnack('Erreur : ${e.toString()}', success: false);
    }
  }

  void _modifierTache(String entrepriseId, String tacheId, String titre, String desc) {
    _tacheTitreController.text = titre;
    _tacheDescController.text = desc;
    _ouvrirFormulaireTache(entrepriseId, isEdition: true, tacheId: tacheId);
  }

  Future<void> _supprimerTache(String entrepriseId, String tacheId) async {
    try {
      await _firestore
          .collection('entreprises')
          .doc(entrepriseId)
          .collection('taches')
          .doc(tacheId)
          .delete();
      _showSnack('Tâche supprimée !', success: true);
    } catch (e) {
      _showSnack('Erreur : ${e.toString()}', success: false);
    }
  }

  // ---------------- UI HELPERS ----------------
  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: success ? const Color(0xFF2E7D32) : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDeleteConfirm(VoidCallback onConfirm, {String title = 'Confirmer', String content = 'Cette action est irréversible.'}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _ouvrirFormulaireAjout({bool isEdition = false, String? entrepriseId}) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    if (isLargeScreen) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: _buildFormAjoutEntreprise(isEdition, entrepriseId),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildFormAjoutEntreprise(isEdition, entrepriseId),
      );
    }
  }

  Widget _buildFormAjoutEntreprise(bool isEdition, String? entrepriseId) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdition ? 'Modifier entreprise' : 'Ajouter entreprise',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nomController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'entreprise *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _directeurController,
              decoration: InputDecoration(
                labelText: 'Nom du dirigeant *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  if (isEdition && entrepriseId != null) {
                    await _firestore.collection('entreprises').doc(entrepriseId).update({
                      'nom': _nomController.text.trim(),
                      'directeur': _directeurController.text.trim(),
                    });
                    Navigator.pop(context);
                    _nomController.clear();
                    _directeurController.clear();
                    _showSnack('Entreprise modifiée avec succès !', success: true);
                  } else {
                    _ajouterEntreprise();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isEdition ? 'MODIFIER' : 'ENREGISTRER'),
            ),
          ],
        ),
      ),
    );
  }

  void _ouvrirFormulaireAjoutSousAgence(String entrepriseId, {bool isEdition = false, String? sousAgenceId}) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    if (isLargeScreen) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: _buildFormAjoutSousAgence(entrepriseId, isEdition, sousAgenceId),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildFormAjoutSousAgence(entrepriseId, isEdition, sousAgenceId),
      );
    }
  }

  Widget _buildFormAjoutSousAgence(String entrepriseId, bool isEdition, String? sousAgenceId) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdition ? 'Modifier sous-agence' : 'Ajouter sous-agence',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _sousAgenceNomController,
            decoration: InputDecoration(
              labelText: 'Nom sous-agence *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sousAgenceVilleController,
            decoration: InputDecoration(
              labelText: 'Ville (optionnel)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (isEdition && sousAgenceId != null) {
                await _firestore
                    .collection('entreprises')
                    .doc(entrepriseId)
                    .collection('sousAgences')
                    .doc(sousAgenceId)
                    .update({
                  'nom': _sousAgenceNomController.text.trim(),
                  'ville': _sousAgenceVilleController.text.trim(),
                });
                Navigator.pop(context);
                _sousAgenceNomController.clear();
                _sousAgenceVilleController.clear();
                _showSnack('Sous-agence modifiée avec succès !', success: true);
              } else {
                _ajouterSousAgence(entrepriseId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEdition ? 'MODIFIER' : 'ENREGISTRER'),
          ),
        ],
      ),
    );
  }

  void _ouvrirFormulaireTache(String entrepriseId, {bool isEdition = false, String? tacheId}) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    if (isLargeScreen) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: _buildFormAjoutTache(entrepriseId, isEdition, tacheId),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildFormAjoutTache(entrepriseId, isEdition, tacheId),
      );
    }
  }

  Widget _buildFormAjoutTache(String entrepriseId, bool isEdition, String? tacheId) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdition ? 'Modifier tâche' : 'Nouvelle tâche',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _tacheTitreController,
            decoration: InputDecoration(
              labelText: 'Titre de la tâche *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tacheDescController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (isEdition && tacheId != null) {
                await _firestore
                    .collection('entreprises')
                    .doc(entrepriseId)
                    .collection('taches')
                    .doc(tacheId)
                    .update({
                  'titre': _tacheTitreController.text.trim(),
                  'description': _tacheDescController.text.trim(),
                });
                Navigator.pop(context);
                _tacheTitreController.clear();
                _tacheDescController.clear();
                _showSnack('Tâche modifiée avec succès !', success: true);
              } else {
                _ajouterTache(entrepriseId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEdition ? 'MODIFIER' : 'ENREGISTRER'),
          ),
        ],
      ),
    );
  }

  Widget _buildSousAgenceCard(String entrepriseId, DocumentSnapshot sousAgence) {
    final nom = sousAgence['nom'] ?? '';
    final ville = sousAgence['ville'] ?? '';
    final date = (sousAgence['dateCreation'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.building_4, color: Color(0xFF2E7D32), size: 20),
        ),
        title: Text(nom, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ville.isNotEmpty) Text('Ville: $ville', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            Text('Créée le: ${DateFormat('dd/MM/yyyy').format(date)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
              onPressed: () => _modifierSousAgence(entrepriseId, sousAgence.id, nom, ville),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirm(() => _supprimerSousAgence(entrepriseId, sousAgence.id),
                  title: 'Supprimer la sous-agence ?', content: 'Cette action est irréversible.'),
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTacheCard(String entrepriseId, DocumentSnapshot tache) {
    final titre = tache['titre'] ?? '';
    final desc = tache['description'] ?? '';
    final date = (tache['dateCreation'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.task_square, color: Color(0xFF2E7D32), size: 20),
        ),
        title: Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (desc.isNotEmpty) Text(desc, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            Text('Créée le: ${DateFormat('dd/MM/yyyy').format(date)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.grey),
              onPressed: () => _modifierTache(entrepriseId, tache.id, titre, desc),
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _showDeleteConfirm(() => _supprimerTache(entrepriseId, tache.id),
                  title: 'Supprimer la tâche ?', content: 'Cette action est irréversible.'),
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrepriseCard(DocumentSnapshot entreprise) {
    final nom = entreprise['nom'];
    final directeur = entreprise['directeur'];
    final date = (entreprise['dateCreation'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2E7D32).withOpacity(0.1),
                const Color(0xFF2E7D32).withOpacity(0.2),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.building_3, color: Color(0xFF2E7D32), size: 24),
        ),
        title: Text(
          nom,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Dirigeant: $directeur',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Créée le: ${DateFormat('dd/MM/yyyy').format(date)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.more_vert, size: 20, color: Theme.of(context).colorScheme.primary),
          ),
          onSelected: (value) {
            if (value == 'edit') {
              _modifierEntreprise(entreprise.id, nom, directeur);
            } else if (value == 'delete') {
              _showDeleteConfirm(() => _supprimerEntreprise(entreprise.id), title: 'Confirmer la suppression', content: 'Voulez-vous vraiment supprimer cette entreprise ?');
            } else if (value == 'addSousAgence') {
              _ouvrirFormulaireAjoutSousAgence(entreprise.id);
            } else if (value == 'addTache') {
              _ouvrirFormulaireTache(entreprise.id);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'addSousAgence',
              child: Row(children: [const Icon(Icons.add_location_alt_outlined, size: 18), const SizedBox(width: 12), const Text('Ajouter une sous-agence')]),
            ),
            PopupMenuItem(
              value: 'addTache',
              child: Row(children: [const Icon(Iconsax.add_square, size: 18), const SizedBox(width: 12), const Text('Ajouter une tâche')]),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [const Icon(Icons.edit_outlined, size: 18), const SizedBox(width: 12), const Text('Modifier')]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [const Icon(Icons.delete_outline, size: 18, color: Colors.red), const SizedBox(width: 12), const Text('Supprimer', style: TextStyle(color: Colors.red))]),
            ),
          ],
        ),
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('entreprises').doc(entreprise.id).collection('sousAgences').snapshots(),
            builder: (context, snapshotSousAgences) {
              final sousAgences = snapshotSousAgences.data?.docs ?? [];
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('entreprises').doc(entreprise.id).collection('taches').snapshots(),
                builder: (context, snapshotTaches) {
                  final taches = snapshotTaches.data?.docs ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats rapides
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(sousAgences.length, 'Sous-agences', Iconsax.building_4),
                            _buildStatItem(taches.length, 'Tâches', Iconsax.task_square),
                          ],
                        ),
                      ),

                      // Sous-agences
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8),
                        child: Text(
                          'Sous‑agences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                      if (sousAgences.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Aucune sous-agence',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          ),
                        )
                      else
                        ...sousAgences.map((s) => _buildSousAgenceCard(entreprise.id, s)).toList(),

                      const SizedBox(height: 16),

                      // Tâches
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tâches',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              '${taches.length} tâche${taches.length != 1 ? 's' : ''}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                      if (taches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            'Aucune tâche définie pour cette entreprise',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                          ),
                        )
                      else
                        ...taches.map((t) => _buildTacheCard(entreprise.id, t)).toList(),

                      const SizedBox(height: 12),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(int count, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher une entreprise...',
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEntrepriseGrid(List<DocumentSnapshot> entreprises) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: entreprises.length,
      itemBuilder: (context, index) => _buildEntrepriseCard(entreprises[index]),
    );
  }

  Widget _buildEntrepriseList(List<DocumentSnapshot> entreprises) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: entreprises.length,
      itemBuilder: (_, index) => _buildEntrepriseCard(entreprises[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Gestion des entreprises',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        toolbarHeight: 90,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.search, size: 24, color: Colors.white),
            ),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _EntrepriseSearchDelegate(_allEntreprises, _modifierEntreprise),
              );
            },
            tooltip: 'Rechercher',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Iconsax.add, size: 24, color: Colors.white),
            ),
            onPressed: () => _ouvrirFormulaireAjout(),
            tooltip: 'Ajouter une entreprise',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 800;
          final maxWidth = isLargeScreen ? 1000.0 : double.infinity;

          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header stats
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('entreprises').snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        return Row(
                          children: [
                            const Icon(Iconsax.buildings_2, color: Color(0xFF2E7D32), size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Entreprises enregistrées',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '$count entreprise${count != 1 ? 's' : ''}',
                                style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search field for large screens
                  if (isLargeScreen) _buildSearchField(),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('entreprises').orderBy('dateCreation', descending: true).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'Erreur de chargement',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Veuillez réessayer plus tard',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Chargement des entreprises...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        _allEntreprises = docs;
                        if (_searchController.text.isEmpty) {
                          _filteredEntreprises = docs;
                        }

                        if (_filteredEntreprises.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.buildings, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                                const SizedBox(height: 24),
                                Text(
                                  _searchController.text.isEmpty ? 'Aucune entreprise enregistrée' : 'Aucun résultat trouvé',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Commencez par ajouter votre première entreprise'
                                      : 'Essayez avec d\'autres termes de recherche',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () => _ouvrirFormulaireAjout(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Iconsax.add, size: 20),
                                  label: const Text('Ajouter une entreprise'),
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            await Future.delayed(const Duration(milliseconds: 300));
                            return;
                          },
                          color: const Color(0xFF2E7D32),
                          child: isLargeScreen
                              ? _buildEntrepriseGrid(_filteredEntreprises)
                              : _buildEntrepriseList(_filteredEntreprises),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EntrepriseSearchDelegate extends SearchDelegate {
  final List<DocumentSnapshot> entreprises;
  final Function(String, String, String) onModify;

  _EntrepriseSearchDelegate(this.entreprises, this.onModify);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = entreprises.where((entreprise) {
      final data = entreprise.data() as Map<String, dynamic>;
      final nom = data['nom']?.toString().toLowerCase() ?? '';
      final directeur = data['directeur']?.toString().toLowerCase() ?? '';
      return nom.contains(query.toLowerCase()) || directeur.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entreprise = results[index];
        final data = entreprise.data() as Map<String, dynamic>;
        final nom = data['nom'];
        final directeur = data['directeur'];
        final date = (data['dateCreation'] as Timestamp).toDate();

        return ListTile(
          leading: const Icon(Iconsax.building_3, color: Color(0xFF2E7D32)),
          title: Text(nom),
          subtitle: Text('Dirigeant: $directeur'),
          trailing: Text(DateFormat('dd/MM/yyyy').format(date)),
          onTap: () {
            close(context, null);
            onModify(entreprise.id, nom, directeur);
          },
        );
      },
    );
  }
}