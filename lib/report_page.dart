/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanningSemainePersonnel extends StatefulWidget {
  const PlanningSemainePersonnel({super.key});

  @override
  State<PlanningSemainePersonnel> createState() => _PlanningSemainePersonnelState();
}

class _PlanningSemainePersonnelState extends State<PlanningSemainePersonnel> {
  // [Tout le code backend reste inchangé...]

  @override
  Widget build(BuildContext context) {
    final joursSemaine = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final jour in joursSemaine) {
      grouped[jour] = _plannings.where((p) => p['jour'] == jour).toList();
    }

    return Scaffold(
        appBar: AppBar(
        title: const Text('Mon Planning de la semaine',
        style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
    )),
    backgroundColor: const Color(0xFF00574B),
    elevation: 0,
    centerTitle: true,
    shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
    bottom: Radius.circular(16),
    ),
    toolbarHeight: 80,
    ),
    body: Container(
    decoration: const BoxDecoration(
    gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F7FA), Color(0xFFE4E8EB)],
    ),
    ),
    child: _loading
    ? const Center(
    child: CircularProgressIndicator.adaptive(
    valueColor: AlwaysStoppedAnimation(Color(0xFF00574B)),
    ),
    )
        : _plannings.isEmpty
    ? Center(
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(
    Icons.calendar_today,
    size: 100,
    color: Colors.grey[400],
    ),
    const SizedBox(height: 16),
    Text(
    'Semaine tranquille !',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: Colors.grey[700],
    ),
    ),
    const SizedBox(height: 8),
    Text(
    'Aucune tâche planifiée cette semaine',
    style: TextStyle(
    fontSize: 14,
    color: Colors.grey[500],
    ),
    ),
    ],
    ),
    )
        : ListView(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
    children: grouped.entries.map((entry) {
    final jour = entry.key;
    final items = entry.value;
    if (items.isEmpty) return const SizedBox();

    return Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
    BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 12,
    offset: const Offset(0, 4),
    ),
    ],
    ),
    child: Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    color: Colors.white,
    child: ExpansionTile(
    tilePadding: const EdgeInsets.symmetric(horizontal: 20),
    childrenPadding: const EdgeInsets.only(bottom: 8),
    leading: Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
    color: const Color(0xFF00574B).withOpacity(0.1),
    shape: BoxShape.circle,
    ),
    child: Center(
    child: Text(
    jour.substring(0, 1),
    style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Color(0xFF00574B),
    ),
    ),
    ),
    title: Text(
    jour,
    style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Color(0xFF2C3E50),
    ),
    children: items.map((planning) {
    final date = (planning['date'] as Timestamp).toDate();
    final statut = planning['statut'] ?? 'en_attente';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (statut) {
    case 'terminee':
    statusColor = const Color(0xFF4CAF50);
    statusIcon = Icons.check_circle_rounded;
    statusText = 'Terminée';
    break;
    case 'inachevee':
    statusColor = const Color(0xFFFF9800);
    statusIcon = Icons.pending_rounded;
    statusText = 'En cours';
    break;
    default:
    statusColor = const Color(0xFF9E9E9E);
    statusIcon = Icons.access_time_rounded;
    statusText = 'En attente';
    }

    return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(12),
    ),
    child: ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    leading: Container(
    width: 8,
    height: 40,
    decoration: BoxDecoration(
    color: statusColor,
    borderRadius: BorderRadius.circular(4),
    ),
    ),
    title: Text(
    planning['tache'],
    style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    ),
    ),
    subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const SizedBox(height: 4),
    Text(
    planning['entreprise'],
    style: TextStyle(
    fontSize: 13,
    color: Colors.grey[600],
    ),
    ),
    const SizedBox(height: 2),
    Text(
    DateFormat('EEE dd MMM yyyy', 'fr_FR').format(date),
    style: TextStyle(
    fontSize: 12,
    color: Colors.grey[500],
    ),
    ),
    ],
    ),
    trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
    Tooltip(
    message: statusText,
    child: Icon(statusIcon, color: statusColor, size: 24),
    ),
    const SizedBox(width: 12),
    PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, color: Colors.grey),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    ),
    onSelected: (value) => _changerStatut(planning, value),
    itemBuilder: (context) => [
    PopupMenuItem(
    value: 'terminee',
    child: Row(
    children: const [
    Icon(Icons.check, color: Color(0xFF4CAF50)),
    SizedBox(width: 8),
    Text('Marquer comme terminée'),
    ],
    ),
    ),
    PopupMenuItem(
    value: 'inachevee',
    child: Row(
    children: const [
    Icon(Icons.pending, color: Color(0xFFFF9800)),
    SizedBox(width: 8),
    Text('Marquer comme en cours'),
    ],
    ),
    ),
    ],
    ),
    ],
    ),
    ),
    );
    }).toList(),
    ),
    ),
    );
    }).toList(),
    ),
    ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanningSemainePersonnel extends StatefulWidget {
  const PlanningSemainePersonnel({super.key});

  @override
  State<PlanningSemainePersonnel> createState() => _PlanningSemainePersonnelState();
}

class _PlanningSemainePersonnelState extends State<PlanningSemainePersonnel> {
  // [Tout le code backend reste inchangé...]
  // ... (toutes les méthodes existantes conservées telles quelles)

  @override
  Widget build(BuildContext context) {
    final joursSemaine = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final jour in joursSemaine) {
      grouped[jour] = _plannings.where((p) => p['jour'] == jour).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Planning Hebdomadaire',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            )),
        backgroundColor: const Color(0xFF00574B), // Teinte plus moderne de vert
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        toolbarHeight: 80,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F7FA), Color(0xFFE4E8EB)],
          ),
        ),
        child: _loading
            ? const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation(Color(0xFF00574B)),
          ),
        )
            : _plannings.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/empty_calendar.png', // Ajoutez cette image dans vos assets
                width: 150,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Semaine tranquille !',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aucune tâche planifiée cette semaine',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: grouped.entries.map((entry) {
            final jour = entry.key;
            final items = entry.value;
            if (items.isEmpty) return const SizedBox();

            return Container(
                margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
            BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
            ),
            ],
            ),
            child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20),
            contentPadding: const EdgeInsets.only(bottom: 8),
            leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
            color: const Color(0xFF00574B).withOpacity(0.1),
            shape: BoxShape.circle,
            ),
            child: Center(
            child: Text(
            jour.substring(0, 1),
            style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00574B),
            ),
            ),
            ),
            title: Text(
            jour,
            style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
            ),
            children: items.map((planning) {
            final date = (planning['date'] as Timestamp).toDate();
            final statut = planning['statut'] ?? 'en_attente';

            Color statusColor;
            IconData statusIcon;
            String statusText;

            switch (statut) {
            case 'terminee':
            statusColor = const Color(0xFF4CAF50);
            statusIcon = Icons.check_circle_rounded;
            statusText = 'Terminée';
            break;
            case 'inachevee':
            statusColor = const Color(0xFFFF9800);
            statusIcon = Icons.pending_rounded;
            statusText = 'En cours';
            break;
            default:
            statusColor = const Color(0xFF9E9E9E);
            statusIcon = Icons.access_time_rounded;
            statusText = 'En attente';
            }

            return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(4),
            ),
            ),
            title: Text(
            planning['tache'],
            style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            ),
            ),
            subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const SizedBox(height: 4),
            Text(
            planning['entreprise'],
            style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            ),
            ),
            const SizedBox(height: 2),
            Text(
            DateFormat('EEE dd MMM yyyy', 'fr_FR').format(date),
            style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            ),
            ),
            ],
            ),
            trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            Tooltip(
            message: statusText,
            child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => _changerStatut(planning, value),
            itemBuilder: (context) => [
            PopupMenuItem(
            value: 'terminee',
            child: Row(
            children: const [
            Icon(Icons.check, color: Color(0xFF4CAF50)),
            SizedBox(width: 8),
            Text('Marquer comme terminée'),
            ],
            ),
            ),
            PopupMenuItem(
            value: 'inachevee',
            child: Row(
            children: const [
            Icon(Icons.pending, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text('Marquer comme en cours'),
            ],
            ),
            ),
            ],
            ),
            ],
            ),
            ),
            );
            }).toList(),
            ),
            ),
            );
          }).toList(),
        ),
      ),
    );
  }
} */

import 'package:flutter/material.dart';

class ReportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rapport')),
      body: Center(child: Text('Page de Rapport', style: TextStyle(fontSize: 24))),
    );

  }
}