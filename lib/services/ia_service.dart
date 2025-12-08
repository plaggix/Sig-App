import 'package:cloud_firestore/cloud_firestore.dart';

Future<Map<String, dynamic>> analyserTendances() async {
  final firestore = FirebaseFirestore.instance;

  final planningsSnap = await firestore.collection('plannings').get();
  final fichesSnap = await firestore.collection('fiches_structures').get();
  final usersSnap = await firestore.collection('users').get();

  // Création d’un dictionnaire UID -> nom
  Map<String, String> userNames = {};
  for (var u in usersSnap.docs) {
    final data = u.data() as Map<String, dynamic>;
    userNames[u.id] = data['name'] ?? "Sans nom";
  }

  Map<String, Map<String, int>> statsEntreprises = {};
  Map<String, Map<String, int>> statsControleurs = {};
  Map<String, int> motsCles = {};

  // Analyse des plannings
  for (var doc in planningsSnap.docs) {
    final p = doc.data() as Map<String, dynamic>;
    String entreprise = p['entreprise'] ?? "Inconnu";
    String controleurId = p['controleurId'] ?? "Inconnu";
    String controleurNom = userNames[controleurId] ?? controleurId; // remplacement UID → nom
    String statut = p['statut'] ?? "en_attente";

    // Stats entreprises
    statsEntreprises.putIfAbsent(entreprise, () => {"total": 0, "inacheves": 0});
    statsEntreprises[entreprise]!["total"] = statsEntreprises[entreprise]!["total"]! + 1;
    if (statut == "inachevée") {
      statsEntreprises[entreprise]!["inacheves"] = statsEntreprises[entreprise]!["inacheves"]! + 1;
    }

    // Stats contrôleurs (avec noms au lieu d’UIDs)
    statsControleurs.putIfAbsent(controleurNom, () => {"total": 0, "inacheves": 0});
    statsControleurs[controleurNom]!["total"] = statsControleurs[controleurNom]!["total"]! + 1;
    if (statut == "inachevée") {
      statsControleurs[controleurNom]!["inacheves"] = statsControleurs[controleurNom]!["inacheves"]! + 1;
    }
  }

  // Liste de mots à ignorer (stopwords français)
  final stopwords = {
    "avec", "pour", "dans", "les", "des", "une", "et", "que", "qui", "sur", "par", "plus", "sans"
  };

  // Analyse des fiches (rapports) avec comptage amélioré
  for (var doc in fichesSnap.docs) {
    final fiche = doc.data() as Map<String, dynamic>;
    if (fiche['lignes'] != null) {
      for (var ligne in fiche['lignes']) {
        String texte = ligne.toString().toLowerCase();
        // enlever ponctuation et chiffres
        texte = texte.replaceAll(RegExp(r'[^\w\s\u00C0-\u017F]', unicode: true), '');
        // split en mots
        final mots = texte.split(RegExp(r'\s+'));
        for (var mot in mots) {
          if (mot.length > 3 && !stopwords.contains(mot)) {
            motsCles[mot] = (motsCles[mot] ?? 0) + 1;
          }
        }
      }
    }
  }

  return {
    "statsEntreprises": statsEntreprises,
    "statsControleurs": statsControleurs,
    "motsCles": motsCles,
  };
}
