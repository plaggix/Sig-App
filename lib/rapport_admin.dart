import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'rapport_table_page.dart';

class AdminRapportsPage extends StatefulWidget {
  const AdminRapportsPage({Key? key}) : super(key: key);

  @override
  State<AdminRapportsPage> createState() => _AdminRapportsPageState();
}

class _AdminRapportsPageState extends State<AdminRapportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 FILTRES
  String _controleurFilter = '';
  String _rapportFilter = '';

  // 🔹 UTILISATEUR SÉLECTIONNÉ
  DocumentSnapshot? _selectedControleur;
  List<DocumentSnapshot> _reports = [];

  final _green = const Color(0xFF2E7D32);
  final _orange = Colors.orange;
  final _grey = Colors.grey;

  @override
  void initState() {
    super.initState();
  }

Future<void> _loadReportsForSelectedControleur() async {
  if (_selectedControleur == null) {
    setState(() => _reports = []);
    return;
  }

  final snap = await _firestore
      .collection('rapports')
      .orderBy('sousAgenceNom')
      .get();

  setState(() {
    _reports = snap.docs;
  });
}

  // =======================
  // UI BUILDERS
  // =======================

  Widget _buildReportCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final sousAgence = data['sousAgenceNom'] ?? '';
    final entreprise = data['entrepriseNom'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RapportTablePage(
              rapportId: doc.id,
              readOnly: true,
              forcedUserUid: _selectedControleur!.id,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withOpacity(0.12),
              ),
              child: Icon(Icons.assignment_rounded, color: _green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$entreprise • $sousAgence',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Créé le ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}',
                        style: TextStyle(color: _grey, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildControleursList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .where('role', isEqualTo: 'contrôleur')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snapshot.data!.docs.where((doc) {
          final name = (doc['name'] ?? '').toString().toLowerCase();
          return _controleurFilter.isEmpty ||
              name.contains(_controleurFilter);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'Aucun contrôleur trouvé',
              style: TextStyle(color: _grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final doc = filtered[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _orange.withOpacity(0.15),
                  child: const Icon(Icons.person_outline, color: Colors.orange),
                ),
                title: Text(doc['name'] ?? 'Contrôleur'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  setState(() {
                    _selectedControleur = doc;
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _loadReportsForSelectedControleur();
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportsList() {
    final filteredReports = _reports.where((doc) {
     final data = doc.data() as Map<String, dynamic>;

     final entreprise = (data['entrepriseNom'] ?? '').toString().toLowerCase();
     final sousAgence = (data['sousAgenceNom'] ?? '').toString().toLowerCase();
     
     final searchTerm = _rapportFilter.toLowerCase();

     final matchRapport = _rapportFilter.isEmpty ||
      entreprise.contains(searchTerm) ||
      sousAgence.contains(searchTerm);

     return matchRapport;
    }).toList();

    if (filteredReports.isEmpty) {  
      return Center(
        child: Text(
          'Aucun rapport trouvé',
          style: TextStyle(color: _grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredReports.length,
      itemBuilder: (_, i) => _buildReportCard(filteredReports[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(_selectedControleur == null
            ? 'Rapports des contrôleurs'
            : 'Rapports • ${_selectedControleur!['name']}'),
        leading: _selectedControleur != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedControleur = null;
                    _reports = [];
                    _rapportFilter = '';
                  });
                },
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔹 FILTRE CONTRÔLEURS
            if (_selectedControleur == null)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rechercher un contrôleur',
                  prefixIcon: Icon(Icons.person_search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() => _controleurFilter = v.trim().toLowerCase());
                },
              ),
            if (_selectedControleur == null) const SizedBox(height: 12),

            // 🔹 FILTRE RAPPORTS
            if (_selectedControleur != null)
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Rechercher un rapport / sous-agence',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  setState(() => _rapportFilter = v.trim().toLowerCase());
                },
              ),
            if (_selectedControleur != null) const SizedBox(height: 16),

            // 🔹 CONTENU
            Expanded(
              child: _selectedControleur == null
                  ? _buildControleursList()
                  : _buildReportsList(),
            ),
          ],
        ),
      ),
    );
  }
}