import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      final userRef = _firestore.collection('users').doc(uid);
      final snap = await userRef.get();

      if (!snap.exists) {
        await userRef.set({
          'uid': uid,
          'email': email,
          'isAdmin': false,
          'role': 'contrôleur',
          'name': email.split('@').first, // par défaut si besoin
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = snap.data()!;
        final updates = <String, dynamic>{
          'lastLoginAt': FieldValue.serverTimestamp(),
        };
        if ((data['uid'] as String?) != uid) updates['uid'] = uid;
        if (data['role'] == null) {
          // si on n’a pas ce champ, on le pose (contrôleur par défaut)
          final isAdmin = (data['isAdmin'] == true);
          updates['role'] = isAdmin ? 'admin' : 'contrôleur';
        }
        if (data['name'] == null || (data['name'] as String).trim().isEmpty) {
          updates['name'] = email.split('@').first;
        }
        if (updates.isNotEmpty) await userRef.update(updates);
      }

      return cred.user;
    } catch (e) {
      print(e);
      return null;
    }
  }


  Future<User?> register(String email, String password, bool isAdminIgnored) async {
    try {
      // 1) Détecter si c’est le premier utilisateur
      final anyUser = await _firestore.collection('users').limit(1).get();
      final isFirstUser = anyUser.docs.isEmpty;

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // 2) Déduire automatiquement isAdmin/role
      final isAdmin = isFirstUser;                  // premier = admin
      final role    = isFirstUser ? 'admin' : 'contrôleur';

      // 3) Définir un name par défaut si tu n’en as pas encore
      final defaultName = email.split('@').first;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'isAdmin': isAdmin,
        'role': role,
        'name': defaultName, // au besoin, tu pourras le modifier plus tard dans le profil
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return cred.user;
    } catch (e) {
      print('erreur lors de la connexion:$e');
      return null;
    }
  }


  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<bool> isAdmin(String uid) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
    return userDoc.exists && userDoc.get('isAdmin') == true;
  }
}
