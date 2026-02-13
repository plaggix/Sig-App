import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'rapport_table_page.dart';


class RapportsPage extends StatefulWidget {
  const RapportsPage({Key? key}) : super(key: key);

  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _currentUser = FirebaseAuth.instance.currentUser;

  late TabController _tabController;

  bool _loading = true;

  // MES RAPPORTS
  List<DocumentSnapshot> _myReports = [];

  // AUTRES RAPPORTS
  List<DocumentSnapshot> _otherUsers = [];
  DocumentSnapshot? _selectedUser;
  List<DocumentSnapshot> _otherReports = [];

  final _green = const Color(0xFF2E7D32);
  final _orange = Colors.orange;
  final _grey = Colors.grey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadMyReports(),
      _loadOtherUsers(),
    ]);
    setState(() => _loading = false);
  }

  // =======================
  // MES RAPPORTS
  // =======================
  Future<void> _loadMyReports() async {
  final snap = await _firestore
      .collection('rapports')
      .orderBy('entrepriseNom')
      .orderBy('sousAgenceNom')
      .get();

  _myReports = snap.docs;
}

  // =======================
  // AUTRES RAPPORTS
  // =======================
  Future<void> _loadOtherUsers() async {
    final snap = await _firestore
        .collection('users')
        .where('role', whereNotIn: ['gestionnaire', 'administrateur'])
        .get();

    _otherUsers = snap.docs
        .where((u) => u.id != _currentUser?.uid)
        .toList();
  }

Future<void> _loadReportsForUser(DocumentSnapshot user) async {
  setState(() {
    _selectedUser = user;
    _otherReports = [];
  });

  final snap = await _firestore
      .collection('rapports')
      .orderBy('sousAgenceNom')
      .get();

  setState(() => _otherReports = snap.docs);
}



  // =======================
  // UI BUILDERS
  // =======================

  Widget _buildReportCard(DocumentSnapshot doc, {bool readOnly = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final sousAgence = data['sousAgenceNom'] ?? 'Sous-agence inconnue';
    final entreprise = data['entrepriseNom'] ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RapportTablePage(
          rapportId: doc.id,
          readOnly: readOnly,
          forcedUserUid: readOnly ? _selectedUser!.id : null,
        ),
      ),
    );
  },
  child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Créé le ${DateFormat('dd/MM/yyyy').format(createdAt)}',
                      style: TextStyle(fontSize: 13, color: _grey),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            readOnly ? Icons.lock_outline : Icons.arrow_forward_ios_rounded,
            size: 18,
            color: readOnly ? _grey : _green,
          ),
        ],
      ),
     ),
    );
  }

  Widget _buildMyReports() {
    if (_myReports.isEmpty) {
      return _buildEmpty('Aucun rapport disponible');
    }

    return ListView.builder(
      itemCount: _myReports.length,
      itemBuilder: (_, i) => _buildReportCard(_myReports[i]),
    );
  }

  Widget _buildOtherReports() {
    if (_selectedUser == null) {
      return ListView.builder(
        itemCount: _otherUsers.length,
        itemBuilder: (_, i) {
          final user = _otherUsers[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _orange.withOpacity(0.15),
              child: const Icon(Icons.person_outline, color: Colors.orange),
            ),
            title: Text(user['name'] ?? user['email'] ?? 'Utilisateur'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _loadReportsForUser(user),
          );
        },
      );
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.arrow_back, color: _green),
          title: const Text('Retour à la liste des utilisateurs'),
          onTap: () => setState(() => _selectedUser = null),
        ),
        Expanded(
          child: _otherReports.isEmpty
              ? _buildEmpty('Aucun rapport pour cet utilisateur')
              : ListView.builder(
                  itemCount: _otherReports.length,
                  itemBuilder: (_, i) =>
                      _buildReportCard(_otherReports[i], readOnly: true),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 72, color: _grey),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: _grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        backgroundColor: _green,
        title: const Text('Rapports', style: TextStyle(color: Colors.white)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Mes Rapports'),
            Tab(text: 'Autres Rapports'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMyReports(),
                _buildOtherReports(),
              ],
            ),
    );
  }
}
