import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoriquesNonTerminePage extends StatefulWidget {
  const HistoriquesNonTerminePage({super.key});

  @override
  State<HistoriquesNonTerminePage> createState() =>
      _HistoriquesNonTerminePageState();
}

class _HistoriquesNonTerminePageState
    extends State<HistoriquesNonTerminePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadNonTerminees();
  }

  Future<void> _loadNonTerminees() async {
    final snapshot = await _firestore
        .collection('plannings')
        .where('statut', isNotEqualTo: 'terminee')
        .orderBy('statut')
        .orderBy('date', descending: true)
        .get();

    setState(() {
      _tasks = snapshot.docs.map((d) => d.data()).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historique des tâches non terminées',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? _buildEmpty()
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView.separated(
                   itemCount: _tasks.length,
                   separatorBuilder: (_, __) => const SizedBox(height: 12),
                   itemBuilder: (_, i) => _buildTaskCard(_tasks[i]),
                  ),
                ),
    );
  }

Widget _buildTaskCard(Map<String, dynamic> t) {
  final statut = t['statut'] ?? '';
  final date = (t['date'] as Timestamp).toDate();
  final List<String> reaffecteeNoms =
      List<String>.from(t['reaffecteeANoms'] ?? []);

  String label;
  Color color;

  if (statut == 'reaffectee') {
    label = 'Réaffectée';
    color = Colors.blue;
  } else {
    label = 'Inachevée';
    color = Colors.orange;
  }

  return Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t['tache'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${t['sousAgence']} • ${t['entreprise']}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd/MM/yyyy').format(date),
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          if (statut == 'reaffectee' && reaffecteeNoms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Réaffectée à ${reaffecteeNoms.join(', ')}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}



  Widget _buildEmpty() {
    return const Center(
      child: Text(
        'Aucune tâche non terminée',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}
