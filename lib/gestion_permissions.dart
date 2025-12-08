import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionPermissionsPage extends StatefulWidget {
  const GestionPermissionsPage({super.key});

  @override
  State<GestionPermissionsPage> createState() => _GestionPermissionsPageState();
}

class _GestionPermissionsPageState extends State<GestionPermissionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _controleurs = [];
  bool _loading = true;

  final List<String> _permissions = [
    'planning',
    'carte_interactive',
    'entreprises_&_taches',
    'rapports',
  ];

  @override
  void initState() {
    super.initState();
    _chargerControleurs();
  }

  Future<void> _chargerControleurs() async {
    setState(() => _loading = true);

    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'contrôleur')
        .get();

    setState(() {
      _controleurs = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sans nom',
          'email': data['email'] ?? '',
          'photoUrl': data['photoUrl'],
          'permissions': Map<String, bool>.from(data['permissions'] ?? {}),
        };
      }).toList();
      _loading = false;
    });
  }

  Future<void> _updatePermission(
      String userId, String permission, bool value) async {
    try {
      final userDoc = _firestore.collection('users').doc(userId);
      await userDoc.set({
        'permissions': {
          permission: value,
        },
        'lastPermissionUpdate': FieldValue.serverTimestamp(),
        'lastPermissionMessage':
        "Le gestionnaire vous a ${value ? 'accordé' : 'retiré'} le droit d'accès à ${_getPermissionLabel(permission)}",
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(value ? Icons.check_circle : Icons.remove_circle,
                  color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Permission ${_getPermissionLabel(permission)} ${value ? 'activée' : 'désactivée'}",
                ),
              ),
            ],
          ),
          backgroundColor:
          value ? const Color(0xFF2E7D32) : Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Erreur: $e')),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  IconData _getPermissionIcon(String permission) {
    switch (permission) {
      case 'planning':
        return Icons.calendar_month;
      case 'carte_interactive':
        return Icons.map;
      case 'taches':
        return Icons.task_alt;
      case 'entreprises':
        return Icons.business;
      case 'rapports':
        return Icons.analytics;
      default:
        return Icons.lock_outline;
    }
  }

  String _getPermissionLabel(String permission) {
    switch (permission) {
      case 'planning':
        return 'Planning';
      case 'carte_interactive':
        return 'Carte interactive';
      case 'taches':
        return 'Tâches';
      case 'entreprises':
        return 'Entreprises';
      case 'rapports':
        return 'Rapports';
      default:
        return permission;
    }
  }

  String _getPermissionDescription(String permission) {
    switch (permission) {
      case 'planning':
        return 'Créer et gérer les plannings';
      case 'carte_interactive':
        return 'Accéder à la carte interactive';
      case 'taches':
        return 'Gérer les tâches';
      case 'entreprises':
        return 'Accéder aux entreprises';
      case 'rapports':
        return 'Voir et générer des rapports';
      default:
        return '';
    }
  }

  Widget _buildPermissionChip(
      String userId, String permission, Map<String, bool> userPermissions) {
    final isActive = userPermissions[permission] ?? false;
    return FilterChip(
      avatar: Icon(
        _getPermissionIcon(permission),
        size: 18,
        color: isActive
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      label: Text(
        _getPermissionLabel(permission),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isActive
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isActive,
      onSelected: (value) {
        setState(() {
          userPermissions[permission] = value;
        });
        _updatePermission(userId, permission, value);
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          width: 1,
        ),
      ),
      tooltip: _getPermissionDescription(permission),
    );
  }

  Widget _buildControleurCard(Map<String, dynamic> user) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        final avatarSize = isCompact ? 44.0 : 56.0;

        return Card(
          margin: EdgeInsets.only(bottom: isCompact ? 12 : 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.all(isCompact ? 12 : 20),
            childrenPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 20,
              vertical: isCompact ? 6 : 8,
            ),
            leading: Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: user['photoUrl'] != null && user['photoUrl'].isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  user['photoUrl'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
                  : Center(
                child: Text(
                  user['name'][0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Contrôleur',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                user['email'],
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.key_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            children: [
              const Divider(),
              SizedBox(height: isCompact ? 12 : 16),
              Text(
                'Permissions d\'accès',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Activez ou désactivez les permissions pour ce contrôleur',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
              ),
              SizedBox(height: isCompact ? 16 : 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _permissions
                          .map((perm) => _buildPermissionChip(
                          user['id'], perm, user['permissions']))
                          .toList(),
                    );
                  } else {
                    return Column(
                      children: _permissions
                          .map((perm) => _buildPermissionChip(
                          user['id'], perm, user['permissions']))
                          .toList(),
                    );
                  }
                },
              ),

              SizedBox(height: isCompact ? 16 : 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 400;
                  return isNarrow
                      ? Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Tout activer'),
                        onPressed: () {
                          setState(() {
                            for (var perm in _permissions) {
                              user['permissions'][perm] = true;
                            }
                          });
                          for (var perm in _permissions) {
                            _updatePermission(
                                user['id'], perm, true);
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Tout désactiver'),
                        onPressed: () {
                          setState(() {
                            for (var perm in _permissions) {
                              user['permissions'][perm] = false;
                            }
                          });
                          for (var perm in _permissions) {
                            _updatePermission(
                                user['id'], perm, false);
                          }
                        },
                      ),
                    ],
                  )
                      : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Tout activer'),
                          onPressed: () {
                            setState(() {
                              for (var perm in _permissions) {
                                user['permissions'][perm] = true;
                              }
                            });
                            for (var perm in _permissions) {
                              _updatePermission(
                                  user['id'], perm, true);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Tout désactiver'),
                          onPressed: () {
                            setState(() {
                              for (var perm in _permissions) {
                                user['permissions'][perm] = false;
                              }
                            });
                            for (var perm in _permissions) {
                              _updatePermission(
                                  user['id'], perm, false);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: isCompact ? 12 : 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final basePadding = isMobile ? 12.0 : 20.0;

    return Scaffold(
      backgroundColor:
      Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        title: Text(
          'Gestion des permissions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: isMobile ? 70 : 90,
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
            onPressed: _chargerControleurs,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _controleurs.isEmpty
          ? const Center(child: Text('Aucun contrôleur'))
          : RefreshIndicator(
        onRefresh: _chargerControleurs,
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: EdgeInsets.all(basePadding),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossCount = constraints.maxWidth > 1000
                        ? 3
                        : constraints.maxWidth > 700
                        ? 2
                        : 1;
                    return GridView.builder(
                      gridDelegate:
                      SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _controleurs.length,
                      itemBuilder: (context, index) =>
                          _buildControleurCard(
                              _controleurs[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
