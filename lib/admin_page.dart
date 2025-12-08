import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Page Administrateur'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Bienvenue Administrateur'),
            ElevatedButton(
              onPressed: () {
      
              },
              child: Text('Supprimer un élément'),
            ),
            ElevatedButton(
              onPressed: () {
              
              },
              child: Text('Accéder à une page spéciale'),
            ),
          ],
        ),
      ),
    );
  }
}
