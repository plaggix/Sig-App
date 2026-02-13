import 'package:cloud_firestore/cloud_firestore.dart';

class MigrationService {
  static Future<void> migrateRapportValidations() async {
    final firestore = FirebaseFirestore.instance;

    final rapportsSnap = await firestore.collection('rapports').get();

    for (final rapportDoc in rapportsSnap.docs) {
      final data = rapportDoc.data();

      final oldValidations = data['validations'];
      if (oldValidations == null || oldValidations is! Map) {
        continue;
      }

      for (final entry in oldValidations.entries) {
        final tacheNom = entry.key;
        final val = entry.value;

        if (val is! Map) continue;

        await rapportDoc.reference
            .collection('validations')
            .add({
          'tacheNom': tacheNom,
          'statut': val['statut'] ?? 'Inconnue',
          'validatedAt': val['validatedAt'] ??
              val['date'] ??
              Timestamp.now(),
          'validatedByUid': val['validatedByUid'] ?? 'migration',
          'observation': val['observation'],
          'solution': val['solution'],
          'isComplete': true,
        });
      }

      print('Rapport ${rapportDoc.id} migré');
    }

    print('Migration terminée');
  }
}
