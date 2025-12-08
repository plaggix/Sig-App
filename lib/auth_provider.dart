import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> register(String name, String email, String password) async {
    try {
      // Vérifier s'il y a déjà des utilisateurs enregistrés
      QuerySnapshot users = await _firestore.collection('users').get();
      bool isFirstUser = users.docs.isEmpty;

      // Création de l'utilisateur dans Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Déterminer le rôle
      String role = isFirstUser ? 'gestionnaire' : 'contrôleur';

      // Stocker les infos de l'utilisateur dans Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception("Erreur lors de l'inscription : $e");
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      throw Exception("Erreur lors de la connexion : $e");
    }
  }
}
