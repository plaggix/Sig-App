import 'package:flutter/material.dart';
import 'creer_planning_page.dart';
import 'taches_controleur.dart';
import 'localisation_page.dart';
import 'report_page.dart';   

class MenuPage extends StatelessWidget {
  final List<String> categories = [
    'Gestion',
  ];

  final List<String> items = [
    'Planning',
    'Tâche',
    'Localisation',
    'Rapport',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightGreen, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: categories.length,
                itemBuilder: (context, categoryIndex) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          categories[categoryIndex],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          itemBuilder: (context, itemIndex) {
                            return GestureDetector(
                              onTap: () {
                               
                                switch (items[itemIndex]) {
                                  case 'Planning':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => PlanningPage()),
                                    );
                                    break;
                                  case 'Tâche':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => TachesDuJourPage()),
                                    );
                                    break;
                                  case 'Localisation':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => LocalisationPage()),
                                    );
                                    break;
                                  case 'Rapport':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ReportPage()),
                                    );
                                    break;
                                }
                              },
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Center(
                                  child: Text(
                                    items[itemIndex],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}