import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_administrateur.dart';
import 'home_controleur.dart';
import 'welcome.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Aucun utilisateur connecté
      return const WelcomePage();
    } else {
      // Utilisateur connecté, on vérifie son rôle
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Scaffold(
              body: Center(child: Text('Erreur de chargement du profil')),
            );
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final role = userData['role'];

          if (role == 'gestionnaire') {
            return const AdminDashboard();
          } else if (role == 'contrôleur') {
            return ControllerDashboard();
          } else {
            return const Scaffold(
              body: Center(child: Text('Rôle non reconnu')),
            );
          }
        },
      );
    }
  }
}
