import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class LocalisationPage extends StatefulWidget {
  const LocalisationPage({super.key});

  @override
  State<LocalisationPage> createState() => _LocalisationPageState();
}

class _LocalisationPageState extends State<LocalisationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _controleurs = [];
  final LatLng _camerounCenter = LatLng(3.848, 11.5021);
  final Distance _distance = const Distance();
  bool _loading = true;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _chargerPositions();
  }

  Future<void> _chargerPositions() async {
    setState(() => _loading = true);

    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'contrôleur')
        .get();

    final controleurs = await Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data();
      final double? lat = data['latitude'];
      final double? lon = data['longitude'];

      if (lat == null || lon == null) return null;

      final address = await _getAddress(lat, lon);
      final dist = _distance.as(LengthUnit.Kilometer, _camerounCenter, LatLng(lat, lon));

      return {
        'name': data['name'] ?? 'Inconnu',
        'lat': lat,
        'lon': lon,
        'adresse': address,
        'distance': dist.toStringAsFixed(1),
        'photoURL': data['photoURL'] ?? '',
      };
    }).toList());

    setState(() {
      _controleurs.clear();
      _controleurs.addAll(controleurs.whereType<Map<String, dynamic>>());
      _loading = false;
    });
  }

  Future<String> _getAddress(double lat, double lon) async {
    final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon');
    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'SIGApp/1.0 (contact@example.com)',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Adresse inconnue';
      }
    } catch (_) {}
    return 'Adresse inconnue';
  }

  Widget _buildControleurCard(Map<String, dynamic> controleur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: controleur['photoURL']?.isNotEmpty == true
              ? ClipOval(
            child: Image.network(
              controleur['photoURL'],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.person, color: Color(0xFF2E7D32)),
            ),
          )
              : const Icon(Icons.person, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          controleur['name'],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              controleur['adresse'],
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${controleur['distance']} km du centre',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.location_on, color: Colors.red[400]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Localisation des contrôleurs',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        toolbarHeight: 90,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, size: 22, color: Colors.white),
            ),
            onPressed: _chargerPositions,
            tooltip: 'Actualiser les positions',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _showList ? Icons.map_outlined : Icons.list_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
            onPressed: () => setState(() => _showList = !_showList),
            tooltip: _showList ? 'Voir la carte' : 'Voir la liste',
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement des positions...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : _controleurs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucun contrôleur localisé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les positions des contrôleurs apparaîtront ici',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _chargerPositions,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
          ],
        ),
      )
          : _showList
          ? Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline, color: Color(0xFF2E7D32), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Contrôleurs en activité',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_controleurs.length} contrôleur${_controleurs.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _controleurs.length,
                itemBuilder: (context, index) => _buildControleurCard(_controleurs[index]),
              ),
            ),
          ],
        ),
      )
          : Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _camerounCenter,
              initialZoom: 6.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sig_app',
              ),
              MarkerLayer(
                markers: _controleurs.map((ctrl) {
                  return Marker(
                    width: 60.0,
                    height: 60.0,
                    point: LatLng(ctrl['lat'], ctrl['lon']),
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(ctrl['name']),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ctrl['adresse'],
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${ctrl['distance']} km du centre',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fermer'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                      ),
                    ),
                  );
                }).toList(),
              )
            ],
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${_controleurs.length} contrôleur${_controleurs.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}