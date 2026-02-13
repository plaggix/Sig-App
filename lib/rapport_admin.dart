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

  String _controleurFilter = '';
  String _rapportFilter = '';

  String? _selectedControleurUid;
  String? _selectedControleurName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: Text(
          _selectedControleurName == null
              ? 'Rapports des contrôleurs'
              : 'Rapports • $_selectedControleurName',
        ),
        leading: _selectedControleurUid != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedControleurUid = null;
                    _selectedControleurName = null;
                  });
                },
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= FILTRES =================
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),

            // ================= CONTENU =================
            Expanded(
              child: _selectedControleurUid == null
                  ? _buildControleursList()
                  : _buildRapportsList(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 🔵 LISTE DES CONTRÔLEURS
  // ============================================================
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
          return const Text('Aucun contrôleur trouvé');
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: Text(doc['name'] ?? 'Contrôleur'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedControleurUid = doc.id;
                    _selectedControleurName = doc['name'];
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 🟢 LISTE DES RAPPORTS DU CONTRÔLEUR
  // ============================================================
  Widget _buildRapportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rapports')
          .where('validatedByUid', isEqualTo: _selectedControleurUid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final sousAgence =
              (data['entrepriseNom'] ?? data['sousAgenceNom'] ?? '').toString().toLowerCase();

          return _rapportFilter.isEmpty ||
              sousAgence.contains(_rapportFilter);
        }).toList();

        if (filtered.isEmpty) {
          return const Text('Aucun rapport trouvé');
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                title: Text(
                  '${data['entrepriseNom']} • ${data['sousAgenceNom']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: data['createdAt'] != null
                    ? Text(
                        'Créé le ${DateFormat('dd/MM/yyyy HH:mm').format(
                          (data['createdAt'] as Timestamp).toDate(),
                        )}',
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RapportTablePage(
                        rapportId: doc.id,
                        readOnly: true, // 🔐 admin = lecture seule
                        forcedUserUid: _selectedControleurUid,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
