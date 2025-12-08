import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PersonalPlanningPage extends StatefulWidget {
  @override
  _PersonalPlanningPageState createState() => _PersonalPlanningPageState();
}

class _PersonalPlanningPageState extends State<PersonalPlanningPage> {
  final List<String> _jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
  final Map<String, List<Activity>> _planning = {
    'Lundi': [],
    'Mardi': [],
    'Mercredi': [],
    'Jeudi': [],
    'Vendredi': [],
    'Samedi': [],
  };

  List<Map<String, String>> _controleurs = [];

  @override
  void initState() {
    super.initState();
    _chargerControleurs();
  }

  Future<void> _chargerControleurs() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final liste = <Map<String, String>>[];
    for (final d in snapshot.docs) {
      final data = d.data();
      final name = (data['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        // on garde l’uid doc.id (ou data['uid'] si tu veux)
        final uid = (data['uid'] as String?) ?? d.id;
        liste.add({'uid': uid, 'name': name});
      }
    }
    // tri par nom (facultatif)
    liste.sort((a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()));
    setState(() => _controleurs = liste);
  }

  Future<void> _migrerUsersPourAjouterUid() async {
    final users = await FirebaseFirestore.instance.collection('users').get();
    for (final doc in users.docs) {
      final data = doc.data();
      if (data['uid'] == null || (data['uid'] as String?)!.isEmpty) {
        await doc.reference.update({'uid': doc.id});
        print('✔ uid ajouté pour ${doc.id}');
      }
    }
  }


  void _ajouterActivite(String jour) {
    showDialog(
      context: context,
      builder: (context) {
        final _activiteController = TextEditingController();
        final _entrepriseController = TextEditingController();
        // Sélection par défaut: le premier contrôleur s’il existe
        Map<String, String>? _controleurSelectionne =
        _controleurs.isNotEmpty ? _controleurs.first : null;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text("Ajouter une activité pour $jour"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _activiteController,
                      decoration: InputDecoration(labelText: 'Nom de l\'activité'),
                    ),
                    TextField(
                      controller: _entrepriseController,
                      decoration: InputDecoration(labelText: 'Nom de l\'entreprise'),
                    ),
                    SizedBox(height: 10),
                    DropdownButtonFormField<Map<String, String>>(
                      value: _controleurSelectionne,
                      items: _controleurs.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c['name']!), // affiche le nom
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _controleurSelectionne = value;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Nom du contrôleur'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_activiteController.text.isNotEmpty &&
                        _entrepriseController.text.isNotEmpty &&
                        _controleurSelectionne != null) {
                      setState(() {
                        _planning[jour]!.add(Activity(
                          id: const Uuid().v4(),
                          jour: jour,
                          activite: _activiteController.text,
                          entreprise: _entrepriseController.text,
                          // stocke les 2 : affichage & liaison fiable
                          controleurName: _controleurSelectionne!['name']!,
                          controleurId: _controleurSelectionne!['uid']!,
                        ));
                      });
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tous les champs sont obligatoires.')),
                      );
                    }
                  },
                  child: Text('Ajouter'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _enregistrerPlanning() async {
    final id = const Uuid().v4();
    final date = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final Map<String, dynamic> data = {
      'id': id,
      'dateCreation': date,
      'jours': _planning.map((jour, activites) => MapEntry(jour, activites.map((a) {
        final map = a.toMap();
        map['date'] = _getDateFromJour(jour);
        return map;
      }).toList())),
    };

    // Sauvegarde globale dans /plannings
    await FirebaseFirestore.instance.collection('plannings').doc(id).set(data);

    // Sauvegarde par utilisateur dans /user_plannings
    for (var jour in _planning.keys) {
      for (var act in _planning[jour]!) {
        final controleurUidAuth = act.controleurId;

        final userPlanningRef = FirebaseFirestore.instance
            .collection('user_plannings')
            .doc(controleurUidAuth)
            .collection('plannings')
            .doc(id);

        // 1. Déclare d’abord activityMap
        final activityMap = act.toMap();
        activityMap['date'] = _getDateFromJour(jour);
        activityMap['controleurId'] = controleurUidAuth;
        activityMap['controleurName'] = act.controleurName;

        // 2. Initialise le document (s’il n’existe pas encore)
        await userPlanningRef.set({
          'id': id,
          'dateCreation': date,
          'jours': {}, // init vide
        }, SetOptions(merge: true));

        // 3. Ajoute l’activité dans le jour approprié
        await userPlanningRef.update({
          'jours.$jour': FieldValue.arrayUnion([activityMap])
        });

        print("Activité ajoutée dans user_plannings/$controleurUidAuth/plannings/$id -> $jour");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Planning enregistré')),
    );
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

  Widget _buildJourCard(String jour) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(jour, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () => _ajouterActivite(jour),
                )
              ],
            ),
            ..._planning[jour]!.map((a) => ListTile(
              title: Text(a.activite),
              subtitle: Text('${a.entreprise} - ${a.controleurName}'),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => _planning[jour]!.remove(a));
                },
              ),
            ))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Créer un planning'),
        backgroundColor: Color(0xFF2E7D32),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _enregistrerPlanning,
          )
        ],
      ),
      body: _controleurs.isEmpty
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: _jours.map((j) => _buildJourCard(j)).toList(),
        ),
      ),
    );
  }
}

class Activity {
  final String id;
  final String jour;
  final String activite;
  final String entreprise;
  final String controleurName; // affichage
  final String controleurId;   // liaison Auth

  Activity({
    required this.id,
    required this.jour,
    required this.activite,
    required this.entreprise,
    required this.controleurName,
    required this.controleurId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'jour': jour,
    'activite': activite,
    'entreprise': entreprise,
    'controleur': controleurName, // pour compatibilité avec l'UI existante
    'controleurId': controleurId,
  };
}
