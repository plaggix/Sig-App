/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

// Modèle de données pour les services
class SigService {
  final String id;
  final String titre;
  final String description;
  final IconData icon;
  final String categorie;

  SigService({required this.id, required this.titre, required this.description, required this.icon, required this.categorie});
}

class HomeMaintenancePage extends StatefulWidget {
  @override
  _HomeMaintenancePageState createState() => _HomeMaintenancePageState();
}

class _HomeMaintenancePageState extends State<HomeMaintenancePage> {
  // Couleurs officielles extraites du site SIG-Sarl
  final Color sigBlue = Color(0xFF1E3A8A); // Bleu profond
  final Color sigOrange = Color(0xFFFF6B00); // Orange d'accentuation
  final Color sigBg = Color(0xFFF4F7F6);

  String selectedCategory = "Tous";
  final List<String> categories = ["Tous", "Réseau", "Télécom", "Tracking", "Maintenance"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: sigBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: sigBlue,
        title: Text("SIG Sarl - Services", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(icon: Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildCategoryFilter(),
          Expanded(
            child: _buildServiceList(),
          ),
        ],
      ),
    );
  }

  // Header Professionnel
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sigBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Solutions Informatiques & Gestion",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          SizedBox(height: 8),
          Text("Maintenance & Installation Professionnelle",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              )),
          SizedBox(height: 15),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                icon: Icon(Icons.search, color: Colors.white),
                hintText: "Chercher un service...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Filtre de catégories Responsive
  Widget _buildCategoryFilter() {
    return Container(
      height: 60,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        padding: EdgeInsets.symmetric(horizontal: 10),
        itemBuilder: (context, index) {
          bool isSelected = selectedCategory == categories[index];
          return GestureDetector(
            onTap: () => setState(() => selectedCategory = categories[index]),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              padding: EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? sigOrange : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : sigBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Liste des services liée à Firebase
  Widget _buildServiceList() {
    return StreamBuilder<QuerySnapshot>(
      // Remplacez 'services' par le nom de votre collection Firebase
      stream: FirebaseFirestore.instance.collection('services').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: sigOrange));
        }

        // Données statiques de secours (si Firebase est vide) basées sur le site
        var docs = snapshot.data?.docs ?? [];
        
        return ListView.builder(
          padding: EdgeInsets.all(15),
          itemCount: docs.isEmpty ? defaultServices.length : docs.length,
          itemBuilder: (context, index) {
            final service = docs.isEmpty ? defaultServices[index] : docs[index];
            
            // Logique de filtrage
            if (selectedCategory != "Tous" && service['categorie'] != selectedCategory) {
              return SizedBox.shrink();
            }

            return _buildServiceCard(service);
          },
        );
      },
    );
  }

  Widget _buildServiceCard(dynamic serviceData) {

    // Extraction sécurisée des données selon que ce soit un DocumentSnapshot ou une Map
  final Map<String, dynamic> service = (serviceData is QueryDocumentSnapshot) 
      ? serviceData.data() as Map<String, dynamic> 
      : serviceData as Map<String, dynamic>;

    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border(left: BorderSide(color: sigOrange, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: sigBlue.withOpacity(0.1),
          child: Icon(_getIcon(service['categorie']), color: sigBlue),
        ),
        title: Text(service['titre'], 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(service['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: sigOrange),
        onTap: () {
          // Action : Ouvrir détails ou demande de devis
          _showServiceDetails(service);
        },
      ),
    );
  }

  IconData _getIcon(String cat) {
    switch (cat) {
      case "Réseau": return Icons.lan;
      case "Télécom": return Icons.settings_phone;
      case "Tracking": return Icons.gps_fixed;
      default: return Icons.build_circle;
    }
  }

  void _showServiceDetails(dynamic service) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service['titre'], style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: sigBlue)),
            Divider(color: sigOrange, thickness: 2, endIndent: 250),
            SizedBox(height: 15),
            Text(service['description'], style: TextStyle(fontSize: 16, height: 1.5)),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: sigBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {}, // Intégrer Firebase pour soumettre une demande
                child: Text("DEMANDER UNE INTERVENTION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Données par défaut issues du site www.sig-sarl.com
  final List<Map<String, dynamic>> defaultServices = [
    {
      "titre": "Audit et Installation Réseau",
      "description": "Conception de réseaux locaux (LAN/WLAN), câblage structuré et sécurisation des données.",
      "categorie": "Réseau"
    },
    {
      "titre": "Téléphonie IP & Visioconférence",
      "description": "Installation de PABX/IPBX et solutions de collaboration à distance pour entreprises.",
      "categorie": "Télécom"
    },
    {
      "titre": "Tracking GPS & Gestion de Flotte",
      "description": "Surveillance en temps réel de vos véhicules et optimisation des trajets via GPS.",
      "categorie": "Tracking"
    },
    {
      "titre": "Maintenance Hardware",
      "description": "Réparation de serveurs, maintenance préventive du parc informatique et imprimantes.",
      "categorie": "Maintenance"
    },
    {
      "titre": "Maintenance Software",
      "description": "Optimisation système, nettoyage virus, et mise à jour des logiciels de gestion (SAGE/MATRIIX).",
      "categorie": "Maintenance"
    },
  ];
}*/