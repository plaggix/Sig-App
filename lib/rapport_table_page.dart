import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RapportTablePage extends StatefulWidget {
  final String rapportId;
  final bool readOnly;
  final String? forcedUserUid;

  const RapportTablePage({
    Key? key,
    required this.rapportId,
    this.readOnly = false,
    this.forcedUserUid,
  }) : super(key: key);

  @override
  State<RapportTablePage> createState() => _RapportTablePageState();
}

class _RapportTablePageState extends State<RapportTablePage> {
  final _firestore = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic>? _rapport;
  Map<String, QueryDocumentSnapshot?> _lastValidationByTache = {};

  bool _loading = true;

  final _green = const Color(0xFF2E7D32);
  final _grey = Colors.grey;

  String get _targetUid => widget.forcedUserUid ?? _user!.uid;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final doc =
        await _firestore.collection('rapports').doc(widget.rapportId).get();
    _rapport = doc.data();
    setState(() => _loading = false);
  }

  // ===================== STREAMS =====================

  Stream<QuerySnapshot> _tableValidationsStream() {
    return _firestore
        .collection('rapports')
        .doc(widget.rapportId)
        .collection('validations')
        .snapshots();
  }

  Stream<QuerySnapshot> _historyValidationsStream() {
    return _firestore
        .collection('rapports')
        .doc(widget.rapportId)
        .collection('validations')
        .where('validatedByUid', isEqualTo: _targetUid)
        .where('isComplete', isEqualTo: true)
        .snapshots();
  }

  // ===================== DIALOG =====================

  void _showObservationDialog(
    BuildContext context,
    DocumentReference validationRef, {
    String? existingObservation,
    String? existingSolution,
  }) {
    final observationCtrl = TextEditingController(text: existingObservation);
    final solutionCtrl = TextEditingController(text: existingSolution);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Observation & Solution'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: observationCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observation',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: solutionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Solution',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            onPressed: () async {
              if (observationCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Une observation est obligatoire'),
                  ),
                );
                return;
              }

              await validationRef.update({
                'observation': observationCtrl.text.trim(),
                'solution': solutionCtrl.text.trim().isEmpty
                    ? null
                    : solutionCtrl.text.trim(),
                'isComplete': true,
              });

              if (mounted) setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // ===================== TABLE STYLE =====================

  Widget _buildProfessionalTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required BoxConstraints constraints,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _grey.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor:
                MaterialStateProperty.all(_green.withOpacity(0.1)),
            columnSpacing: 20,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F7),
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          '${_rapport!['entrepriseNom']} • ${_rapport!['sousAgenceNom']}',
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.readOnly
                      ? 'Historique des validations'
                      : 'Historique de mes validations',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _green),
                ),
                const SizedBox(height: 16),

                // ===================== TABLEAU 1 (UNIQUEMENT SI PAS READONLY) =====================
                if (!widget.readOnly)
                  StreamBuilder<QuerySnapshot>(
                    stream: _tableValidationsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final docs = snapshot.data!.docs;
                      _lastValidationByTache.clear();

                      for (final doc in docs) {
                        final tache = doc['tacheNom'];
                        if (!_lastValidationByTache.containsKey(tache)) {
                          _lastValidationByTache[tache] = doc;
                        }
                      }

                      return _buildProfessionalTable(
                        constraints: constraints,
                        columns: const [
                          DataColumn(label: Text('Tâche')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Date & Heure')),
                          DataColumn(label: Text('Action')),
                        ],
                        rows: _lastValidationByTache.entries.map((e) {
                          final v = e.value!;
                          final isComplete = v['isComplete'] == true;

                          return DataRow(cells: [
                            DataCell(Text(e.key)),
                            DataCell(Text(v['statut'] ?? '—')),
                            DataCell(Text(
                              v['validatedAt'] != null
                                  ? DateFormat('dd/MM HH:mm').format(
                                      (v['validatedAt'] as Timestamp)
                                          .toDate())
                                  : '—',
                            )),
                            DataCell(
                              IconButton(
                                icon: Icon(
                                  isComplete
                                      ? Icons.edit
                                      : Icons.check_circle,
                                  color: isComplete
                                      ? Colors.blue
                                      : _green,
                                ),
                                onPressed: () => _showObservationDialog(
                                  context,
                                  v.reference,
                                  existingObservation: v['observation'],
                                  existingSolution: v['solution'],
                                ),
                              ),
                            ),
                          ]);
                        }).toList(),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // ===================== RECHERCHE =====================
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher par date ou jour',
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
                const SizedBox(height: 20),

                // ===================== HISTORIQUE COMPLET =====================
                StreamBuilder<QuerySnapshot>(
                  stream: _historyValidationsStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final filtered = snapshot.data!.docs.where((doc) {
                      final ts = doc['validatedAt'] as Timestamp?;
                      if (ts == null) return false;
                      final date =
                          DateFormat('dd/MM/yyyy').format(ts.toDate());
                      final day = DateFormat('EEEE', 'fr_FR')
                          .format(ts.toDate())
                          .toLowerCase();
                      return date.contains(_searchQuery) ||
                          day.contains(_searchQuery.toLowerCase());
                    }).toList();

                    if (filtered.isEmpty) {
                      return Text('Aucun historique trouvé',
                          style: TextStyle(color: _grey));
                    }

                    return _buildProfessionalTable(
                      constraints: constraints,
                      columns: const [
                        DataColumn(label: Text('Tâche')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Observation')),
                        DataColumn(label: Text('Solution')),
                      ],
                      rows: filtered.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return DataRow(cells: [
                          DataCell(Text(d['tacheNom'] ?? '—')),
                          DataCell(Text(DateFormat('dd/MM/yyyy HH:mm')
                              .format(
                                  (d['validatedAt'] as Timestamp).toDate()))),
                          DataCell(Text(d['observation'] ?? '—')),
                          DataCell(Text(d['solution'] ?? '—')),
                        ]);
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
