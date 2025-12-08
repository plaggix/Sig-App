import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class CreationFicheControlePage extends StatefulWidget {
  const CreationFicheControlePage({super.key});

  @override
  State<CreationFicheControlePage> createState() => _CreationFicheControlePageState();
}

class _CreationFicheControlePageState extends State<CreationFicheControlePage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  String? _selectedSousAgence;
  List<String> _sousAgences = [];

  // Structure temporaire pour créer une nouvelle fiche
  List<String> _colonnes = ['Champ 1'];
  List<Map<String, dynamic>> _lignes = [];

  // fiches existantes (documents)
  List<DocumentSnapshot> _fiches = [];
  bool _loading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Design System Material 3
  ColorScheme get _colorScheme => ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    brightness: Theme.of(context).brightness,
  );

  static const double _cardRadius = 16.0;
  static const double _elementSpacing = 16.0;
  static const Duration _animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _chargerSousAgences();
    _chargerFiches();
    _ajouterLigne().then((_) {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ---------- Chargement ----------
  Future<void> _chargerSousAgences() async {
    final snap = await _firestore.collectionGroup('sousAgences').get();
    setState(() {
      _sousAgences = snap.docs
          .map((e) => (e.data() as Map<String, dynamic>)['nom']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });
  }

  Future<void> _chargerFiches() async {
    final snap = await _firestore.collection('fiches_structures').orderBy('sousAgence').get();
    setState(() {
      _fiches = snap.docs;
      _loading = false;
    });
  }

  // ---------- Création structure ----------
  Future<void> _ajouterColonne() async {
    setState(() {
      _colonnes.add('Champ ${_colonnes.length + 1}');
      for (var ligne in _lignes) {
        final vals = List<String>.from(ligne['valeurs'] as List, growable: true);
        vals.add('');
        ligne['valeurs'] = vals;
      }
    });
  }

  void _supprimerColonne(int index) {
    setState(() {
      _colonnes.removeAt(index);
      for (var ligne in _lignes) {
        final vals = ligne['valeurs'] as List;
        if (index < vals.length) vals.removeAt(index);
      }
    });
  }

  Future<void> _ajouterLigne() async {
    setState(() {
      _lignes.add({
        'fusionner': false,
        'valeurs': List<String>.filled(_colonnes.length, '', growable: true),
      });
    });
  }

  void _supprimerLigne(int index) {
    setState(() {
      _lignes.removeAt(index);
    });
  }

  Future<void> _sauvegarderStructure() async {
    if (_selectedSousAgence == null || _selectedSousAgence!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez choisir une sous-agence'),
          backgroundColor: _colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
          action: SnackBarAction(
            label: 'OK',
            textColor: _colorScheme.onErrorContainer,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      return;
    }

    final id = const Uuid().v4();
    await _firestore.collection('fiches_structures').doc(id).set({
      'id': id,
      'sousAgence': _selectedSousAgence,
      'colonnes': _colonnes,
      'lignes': _lignes,
      'fusions': <Map<String, int>>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Structure enregistrée avec succès'),
        backgroundColor: _colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        action: SnackBarAction(
          label: 'OK',
          textColor: _colorScheme.onPrimary,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );

    setState(() {
      _selectedSousAgence = null;
      _colonnes = ['Champ 1'];
      _lignes.clear();
    });

    await _ajouterLigne();
    _chargerFiches();
  }

  // ---------- Widgets améliorés ----------
  Widget _buildColumnChip(int index) {
    return AnimatedContainer(
      duration: _animationDuration,
      margin: const EdgeInsets.only(bottom: 8, right: 8),
      child: Chip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_column_outlined, size: 16, color: _colorScheme.onPrimaryContainer),
            const SizedBox(width: 4),
            Text(
              'Champ ${index + 1}',
              style: TextStyle(fontSize: 12, color: _colorScheme.onPrimaryContainer),
            ),
          ],
        ),
        backgroundColor: _colorScheme.primaryContainer,
        deleteIcon: Icon(Icons.close, size: 16, color: _colorScheme.onPrimaryContainer),
        onDeleted: _colonnes.length > 1 ? () => _supprimerColonne(index) : null,
      ),
    );
  }

  Widget _buildColumnInput(int index) {
    return AnimatedContainer(
      duration: _animationDuration,
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: _colorScheme.surfaceVariant.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.view_column_outlined, size: 20, color: _colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _colonnes[index],
                  onChanged: (val) => _colonnes[index] = val,
                  decoration: InputDecoration(
                    labelText: 'Nom du champ ${index + 1}',
                    border: InputBorder.none,
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  style: TextStyle(color: _colorScheme.onSurface),
                ),
              ),
              if (_colonnes.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: _colorScheme.error),
                  onPressed: () => _supprimerColonne(index),
                  tooltip: 'Supprimer cette colonne',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowCard(int index) {
    final ligne = _lignes[index];
    final int requiredLength = _colonnes.length;
    var vals = List<String>.from(ligne['valeurs'] as List, growable: true);
    if (vals.length < requiredLength) {
      vals.addAll(List<String>.filled(requiredLength - vals.length, '', growable: true));
    } else if (vals.length > requiredLength) {
      vals = List<String>.from(vals.sublist(0, requiredLength), growable: true);
    }
    ligne['valeurs'] = vals;

    return AnimatedContainer(
      duration: _animationDuration,
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.table_rows_outlined, size: 20, color: _colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Ligne ${index + 1}', style: TextStyle(fontWeight: FontWeight.w600, color: _colorScheme.onSurface)),
                  const Spacer(),
                  Switch(
                    value: ligne['fusionner'] ?? false,
                    onChanged: (val) => setState(() => ligne['fusionner'] = val),
                    activeColor: _colorScheme.primary,
                  ),
                  Text('Fusionner', style: TextStyle(fontSize: 12, color: _colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: _colorScheme.error),
                    onPressed: () => _supprimerLigne(index),
                    tooltip: 'Supprimer cette ligne',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_colonnes.length, (j) {
                if (ligne['fusionner'] && j != 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: TextFormField(
                    initialValue: (ligne['valeurs'] as List)[j]?.toString() ?? '',
                    onChanged: (val) => (ligne['valeurs'] as List)[j] = val,
                    decoration: InputDecoration(
                      labelText: ligne['fusionner'] ? 'Valeur fusionnée' : _colonnes[j],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: _colorScheme.surfaceVariant.withOpacity(0.2),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFicheCard(Map<String, dynamic> data) {
    final colonnes = (data['colonnes'] as List?)?.map((c) => c?.toString() ?? '').toList() ?? <String>[];
    final lignes = (data['lignes'] as List?)
        ?.map((r) => {
      'fusionner': (r as Map<String, dynamic>)['fusionner'] ?? false,
      'valeurs': List<String>.from(((r as Map<String, dynamic>)['valeurs'] ?? []).map((v) => v?.toString() ?? '')),
    })
        .toList() ?? <Map<String, dynamic>>[];
    final List<Map<String, int>> fusions = (data['fusions'] as List?)
        ?.map((f) => {
      'startRow': (f['startRow'] as num?)?.toInt() ?? 0,
      'startCol': (f['startCol'] as num?)?.toInt() ?? 0,
      'endRow': (f['endRow'] as num?)?.toInt() ?? 0,
      'endCol': (f['endCol'] as num?)?.toInt() ?? 0,
    })
        .toList() ?? [];

    bool isCovered(int r, int c) {
      for (var f in fusions) {
        if (r >= f['startRow']! && r <= f['endRow']! && c >= f['startCol']! && c <= f['endCol']!) {
          return true;
        }
      }
      return false;
    }

    Map<String, int>? getFusion(int r, int c) {
      for (var f in fusions) {
        if (r >= f['startRow']! && r <= f['endRow']! && c >= f['startCol']! && c <= f['endCol']!) {
          return f;
        }
      }
      return null;
    }

    Widget buildCell(String text, {int row = 0, int col = 0, bool isHeader = false}) {
      final fusion = getFusion(row, col);
      if (fusion != null) {
        if (!(row == fusion['startRow'] && col == fusion['startCol'])) {
          return const SizedBox.shrink();
        }
        final fusionCols = fusion['endCol']! - fusion['startCol']! + 1;
        final fusionRows = fusion['endRow']! - fusion['startRow']! + 1;

        return Container(
          width: 100.0 * fusionCols,
          height: 40.0 * fusionRows,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHeader ? _colorScheme.primary.withOpacity(0.1) : _colorScheme.surface,
            border: Border.all(color: _colorScheme.outline.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
              color: isHeader ? _colorScheme.primary : _colorScheme.onSurface,
            ),
          ),
        );
      }

      return Container(
        width: 100,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isHeader ? _colorScheme.primary.withOpacity(0.1) : _colorScheme.surface,
          border: Border.all(color: _colorScheme.outline.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
            color: isHeader ? _colorScheme.primary : _colorScheme.onSurface,
          ),
        ),
      );
    }

    final timestamp = data['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final dateStr = date != null ? 'Créé le ${date.day}/${date.month}/${date.year}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.table_chart_outlined, color: _colorScheme.primary, size: 20),
        ),
        title: Text(
          data['sousAgence']?.toString() ?? 'Sous-agence inconnue',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _colorScheme.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${colonnes.length} colonnes • ${lignes.length} lignes'),
            if (dateStr.isNotEmpty) Text(dateStr, style: TextStyle(fontSize: 12, color: _colorScheme.onSurfaceVariant)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: _colorScheme.onSurfaceVariant),
          onSelected: (value) {
            switch (value) {
              case 'modifier':
                _modifierFiche(data);
                break;
              case 'dupliquer':
                _dupliquerFiche(data);
                break;
              case 'supprimer':
                _supprimerFiche(data['id']?.toString() ?? '');
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'modifier',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: _colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Modifier'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'dupliquer',
              child: Row(
                children: [
                  Icon(Icons.copy_outlined, color: _colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Dupliquer'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'supprimer',
              child: Row(
                children: [
                  Icon(Icons.delete_outlined, color: _colorScheme.error),
                  const SizedBox(width: 8),
                  const Text('Supprimer'),
                ],
              ),
            ),
          ],
        ),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                Row(
                  children: List.generate(colonnes.length,
                          (c) => buildCell(colonnes[c], row: 0, col: c, isHeader: true)),
                ),
                ...List.generate(lignes.length, (r) {
                  final vals = List<String>.from(lignes[r]['valeurs'] ?? []);
                  if (vals.length < colonnes.length) {
                    vals.addAll(List<String>.filled(colonnes.length - vals.length, ''));
                  }
                  return Row(
                    children: List.generate(
                      colonnes.length,
                          (c) => buildCell(vals[c], row: r + 1, col: c),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Actions supplémentaires pour grands écrans
          if (MediaQuery.of(context).size.width > 600)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: () => _modifierFiche(data),
                  style: FilledButton.styleFrom(
                    backgroundColor: _colorScheme.primaryContainer,
                    foregroundColor: _colorScheme.onPrimaryContainer,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 4),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _dupliquerFiche(data),
                  style: FilledButton.styleFrom(
                    backgroundColor: _colorScheme.secondaryContainer,
                    foregroundColor: _colorScheme.onSecondaryContainer,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_outlined, size: 18),
                      SizedBox(width: 4),
                      Text('Dupliquer'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => _supprimerFiche(data['id']?.toString() ?? ''),
                  style: FilledButton.styleFrom(
                    backgroundColor: _colorScheme.errorContainer,
                    foregroundColor: _colorScheme.onErrorContainer,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outlined, size: 18),
                      SizedBox(width: 4),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _colorScheme.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200,
                height: 20,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: _colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Créer une structure de fiche',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _colorScheme.primary,
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: 90,
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _fadeAnimation.value) * 20),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: isLargeScreen ? _buildDesktopLayout() : _buildMobileLayout(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _buildCreationSection(),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 1,
          child: _buildExistingFichesSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCreationSection(),
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 20),
        _buildExistingFichesSection(),
      ],
    );
  }

  Widget _buildCreationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.create_outlined, color: _colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Créer une nouvelle fiche',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _colorScheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sous-agence
            Text('Sous-agence', style: TextStyle(fontWeight: FontWeight.w500, color: _colorScheme.onSurface)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSousAgence,
              items: _sousAgences.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedSousAgence = val),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              style: TextStyle(color: _colorScheme.onSurface),
            ),
            const SizedBox(height: 20),

            // Colonnes
            Row(
              children: [
                Text('Colonnes', style: TextStyle(fontWeight: FontWeight.w500, color: _colorScheme.onSurface)),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _ajouterColonne,
                  style: FilledButton.styleFrom(
                    backgroundColor: _colorScheme.primaryContainer,
                    foregroundColor: _colorScheme.onPrimaryContainer,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 4),
                      Text('Colonne'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_colonnes.length, (i) => _buildColumnInput(i)),

            const SizedBox(height: 20),

            // Lignes
            Row(
              children: [
                Text('Lignes', style: TextStyle(fontWeight: FontWeight.w500, color: _colorScheme.onSurface)),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: _ajouterLigne,
                  style: FilledButton.styleFrom(
                    backgroundColor: _colorScheme.secondaryContainer,
                    foregroundColor: _colorScheme.onSecondaryContainer,
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 4),
                      Text('Ligne'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_lignes.length, (i) => _buildRowCard(i)),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sauvegarderStructure,
                style: FilledButton.styleFrom(
                  backgroundColor: _colorScheme.primary,
                  foregroundColor: _colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_outlined),
                    SizedBox(width: 8),
                    Text('Enregistrer la structure', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingFichesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _colorScheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt_outlined, color: _colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Fiches enregistrées',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            _buildLoadingSkeleton()
          else if (_fiches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.description_outlined, size: 60, color: _colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune fiche enregistrée',
                    style: TextStyle(color: _colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ],
              ),
            )
          else
            Column(children: _fiches.map((doc) => _buildFicheCard(doc.data() as Map<String, dynamic>)).toList()),
        ],
      ),
    );
  }

  Future<void> _dupliquerFiche(Map<String, dynamic> ficheData) async {
    String? nouvelleSousAgence;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Dupliquer la fiche"),
          content: DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: "Nouvelle sous-agence",
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            items: _sousAgences
                .where((e) => e != (ficheData['sousAgence'] ?? ''))
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => nouvelleSousAgence = val,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler")
            ),
            ElevatedButton(
              onPressed: () {
                if (nouvelleSousAgence != null && nouvelleSousAgence!.isNotEmpty) {
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Veuillez sélectionner une sous-agence différente."),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
              ),
              child: const Text("Dupliquer"),
            ),
          ],
        );
      },
    );

    if (nouvelleSousAgence == null) return;

    final id = const Uuid().v4();
    final nouvelleFiche = Map<String, dynamic>.from(ficheData)
      ..['id'] = id
      ..['sousAgence'] = nouvelleSousAgence
      ..['createdAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('fiches_structures').doc(id).set(nouvelleFiche);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fiche dupliquée avec succès'),
        backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
    _chargerFiches();
  }

  // ---------- Suppression ----------
  Future<void> _supprimerFiche(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Voulez-vous vraiment supprimer cette fiche ?"),
        actions: [
          TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(false)
          ),
          ElevatedButton(
              child: const Text("Supprimer"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true)
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('fiches_structures').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fiche supprimée avec succès"),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        ),
      );
      _chargerFiches();
    }
  }

  // ---------- MODIFIER : 4 options (entry point) ----------
  void _modifierFiche(Map<String, dynamic> ficheData) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Que souhaitez-vous faire ?"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: Color(0xFF2E7D32)),
                  title: const Text("Modifier les données du tableau"),
                  onTap: () {
                    Navigator.pop(context);
                    _modifierDonnees(ficheData);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_chart_outlined, color: Color(0xFF2E7D32)),
                  title: const Text("Insérer une colonne / ligne"),
                  onTap: () {
                    Navigator.pop(context);
                    _insererColonneOuLigne(ficheData);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline, color: Color(0xFF2E7D32)),
                  title: const Text("Supprimer une colonne / ligne"),
                  onTap: () {
                    Navigator.pop(context);
                    _supprimerColonneOuLigne(ficheData);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.merge_outlined, color: Color(0xFF2E7D32)),
                  title: const Text("Fusionner et centrer des cellules"),
                  onTap: () {
                    Navigator.pop(context);
                    _fusionnerEtCentrer(ficheData);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- Option 1 : Modifier les données (colonnes + cellules) ----------
  Future<void> _modifierDonnees(Map<String, dynamic> ficheData) async {
    // Copies locales
    List<String> cols = List<String>.from(ficheData['colonnes'] ?? []);
    List<Map<String, dynamic>> rows = (ficheData['lignes'] as List?)
        ?.map((r) => {
      'fusionner': (r as Map<String, dynamic>)['fusionner'] ?? false,
      'valeurs': List<String>.from(
        ((r as Map<String, dynamic>)['valeurs'] ?? []).map((v) => v?.toString() ?? ''),
        growable: true,
      ),
    })
        .toList() ?? [];

    final docId = ficheData['id']?.toString();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return Dialog(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.85,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    const Text('Modifier les données', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Colonnes:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...List.generate(cols.length, (i) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: cols[i],
                                      onChanged: (v) => setStateDialog(() => cols[i] = v),
                                      decoration: InputDecoration(labelText: 'Champ ${i + 1}'),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: cols.length > 1
                                        ? () {
                                      setStateDialog(() {
                                        cols.removeAt(i);
                                        for (var r in rows) {
                                          final vals = r['valeurs'] as List;
                                          if (i < vals.length) vals.removeAt(i);
                                        }
                                      });
                                    }
                                        : null,
                                  ),
                                ],
                              );
                            }),
                            TextButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  cols.add('Champ ${cols.length + 1}');
                                  for (var r in rows) {
                                    (r['valeurs'] as List).add('');
                                  }
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter une colonne'),
                            ),
                            const SizedBox(height: 12),
                            const Text('Lignes / Cellules:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...List.generate(rows.length, (ri) {
                              final row = rows[ri];
                              // ensure length
                              final int requiredLength = cols.length;
                              var vals = List<String>.from(row['valeurs'] as List, growable: true);
                              if (vals.length < requiredLength) {
                                vals.addAll(List<String>.filled(requiredLength - vals.length, '', growable: true));
                              } else if (vals.length > requiredLength) {
                                vals = List<String>.from(vals.sublist(0, requiredLength), growable: true);
                              }
                              row['valeurs'] = vals;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: row['fusionner'] == true,
                                            onChanged: (v) => setStateDialog(() => row['fusionner'] = v ?? false),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Fusionner cette ligne'),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () {
                                              setStateDialog(() {
                                                rows.removeAt(ri);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Column(
                                        children: List.generate(cols.length, (ci) {
                                          if (row['fusionner'] == true && ci != 0) {
                                            return const SizedBox.shrink();
                                          }
                                          return TextFormField(
                                            initialValue: (row['valeurs'] as List)[ci]?.toString() ?? '',
                                            onChanged: (v) => (row['valeurs'] as List)[ci] = v,
                                            decoration: InputDecoration(labelText: row['fusionner'] == true ? 'Valeur fusionnée' : cols[ci]),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  rows.add({
                                    'fusionner': false,
                                    'valeurs': List<String>.filled(cols.length, ''),
                                  });
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter une ligne'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (docId == null) return;
                            await _firestore.collection('fiches_structures').doc(docId).update({
                              'colonnes': cols,
                              'lignes': rows,
                            });
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche mise à jour')));
                            _chargerFiches();
                          },
                          child: const Text('Enregistrer'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  // ---------- Option 2 : Insérer colonne / ligne ----------
  Future<void> _insererColonneOuLigne(Map<String, dynamic> ficheData) async {
    final docId = ficheData['id']?.toString();
    if (docId == null) return;

    String type = 'colonne'; // 'colonne' ou 'ligne'
    int position = 0;

    // local copies
    List<String> cols = List<String>.from(ficheData['colonnes'] ?? []);
    List<Map<String, dynamic>> rows = (ficheData['lignes'] as List?)
        ?.map((r) => {
      'fusionner': (r as Map<String, dynamic>)['fusionner'] ?? false,
      'valeurs': List<String>.from(
        ((r as Map<String, dynamic>)['valeurs'] ?? []).map((v) => v?.toString() ?? ''),
        growable: true,
      ),
    })
        .toList() ?? [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Insérer"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Colonne'),
                        leading: Radio<String>(
                          value: 'colonne',
                          groupValue: type,
                          onChanged: (v) => setStateDialog(() => type = v!),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('Ligne'),
                        leading: Radio<String>(
                          value: 'ligne',
                          groupValue: type,
                          onChanged: (v) => setStateDialog(() => type = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (type == 'colonne')
                  DropdownButton<int>(
                    value: position,
                    isExpanded: true,
                    items: List.generate(cols.length + 1, (i) {
                      final label = i == 0 ? 'Au début (avant ${cols.first})' : 'Après ${cols[i - 1]} (position $i)';
                      return DropdownMenuItem(value: i, child: Text(label));
                    }),
                    onChanged: (v) => setStateDialog(() => position = v ?? 0),
                  )
                else
                  DropdownButton<int>(
                    value: position,
                    isExpanded: true,
                    items: List.generate(rows.length + 1, (i) {
                      final label = i == 0 ? 'Avant la première ligne' : 'Après la ligne ${i}';
                      return DropdownMenuItem(value: i, child: Text(label));
                    }),
                    onChanged: (v) => setStateDialog(() => position = v ?? 0),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  // apply insertion
                  if (type == 'colonne') {
                    // insert column in cols at index position
                    cols.insert(position, 'Champ ${cols.length + 1}');
                    for (var r in rows) {
                      (r['valeurs'] as List).insert(position, '');
                    }
                  } else {
                    // insert row at position
                    rows.insert(position, {
                      'fusionner': false,
                      'valeurs': List<String>.filled(cols.length, ''),
                    });
                  }

                  // update fusions indexes if present
                  List<Map<String, int>> fusions = (ficheData['fusions'] as List?)
                      ?.map((f) => {
                    'startRow': (f['startRow'] as num?)?.toInt() ?? 0,
                    'startCol': (f['startCol'] as num?)?.toInt() ?? 0,
                    'endRow': (f['endRow'] as num?)?.toInt() ?? 0,
                    'endCol': (f['endCol'] as num?)?.toInt() ?? 0,
                  })
                      .toList() ??
                      [];

                  if (type == 'colonne') {
                    for (var f in fusions) {
                      if (f['startCol']! >= position) {
                        f['startCol'] = f['startCol']! + 1;
                        f['endCol'] = f['endCol']! + 1;
                      } else if (f['endCol']! >= position) {
                        // fusion intersects insertion - extend endCol by 1
                        f['endCol'] = f['endCol']! + 1;
                      }
                    }
                  } else {
                    for (var f in fusions) {
                      if (f['startRow']! >= position) {
                        f['startRow'] = f['startRow']! + 1;
                        f['endRow'] = f['endRow']! + 1;
                      } else if (f['endRow']! >= position) {
                        f['endRow'] = f['endRow']! + 1;
                      }
                    }
                  }

                  await _firestore.collection('fiches_structures').doc(docId).update({
                    'colonnes': cols,
                    'lignes': rows,
                    'fusions': fusions,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Insertion effectuée")));
                  _chargerFiches();
                },
                child: const Text('Insérer'),
              )
            ],
          );
        });
      },
    );
  }

  // ---------- Option 3 : Supprimer colonne / ligne ----------
  Future<void> _supprimerColonneOuLigne(Map<String, dynamic> ficheData) async {
    final docId = ficheData['id']?.toString();
    if (docId == null) return;

    String type = 'colonne';
    int position = 0;

    List<String> cols = List<String>.from(ficheData['colonnes'] ?? []);
    List<Map<String, dynamic>> rows = (ficheData['lignes'] as List?)
        ?.map((r) => {
      'fusionner': (r as Map<String, dynamic>)['fusionner'] ?? false,
      'valeurs': List<String>.from(
        ((r as Map<String, dynamic>)['valeurs'] ?? []).map((v) => v?.toString() ?? ''),
        growable: true,
      ),
    })
        .toList() ?? [];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Supprimer"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Colonne'),
                        leading: Radio<String>(
                          value: 'colonne',
                          groupValue: type,
                          onChanged: (v) => setStateDialog(() => type = v!),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('Ligne'),
                        leading: Radio<String>(
                          value: 'ligne',
                          groupValue: type,
                          onChanged: (v) => setStateDialog(() => type = v!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (type == 'colonne')
                  DropdownButton<int>(
                    value: position,
                    isExpanded: true,
                    items: List.generate(cols.length, (i) {
                      final label = '${cols[i]} (index $i)';
                      return DropdownMenuItem(value: i, child: Text(label));
                    }),
                    onChanged: (v) => setStateDialog(() => position = v ?? 0),
                  )
                else
                  DropdownButton<int>(
                    value: position,
                    isExpanded: true,
                    items: List.generate(rows.length, (i) {
                      final label = 'Ligne ${i + 1}';
                      return DropdownMenuItem(value: i, child: Text(label));
                    }),
                    onChanged: (v) => setStateDialog(() => position = v ?? 0),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  // apply deletion
                  List<Map<String, int>> fusions = (ficheData['fusions'] as List?)
                      ?.map((f) => {
                    'startRow': (f['startRow'] as num?)?.toInt() ?? 0,
                    'startCol': (f['startCol'] as num?)?.toInt() ?? 0,
                    'endRow': (f['endRow'] as num?)?.toInt() ?? 0,
                    'endCol': (f['endCol'] as num?)?.toInt() ?? 0,
                  })
                      .toList() ??
                      [];

                  if (type == 'colonne') {
                    // remove column at position
                    if (position < 0 || position >= cols.length) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position invalide')));
                      return;
                    }
                    cols.removeAt(position);
                    for (var r in rows) {
                      (r['valeurs'] as List).removeAt(position);
                    }

                    // update fusions; if a fusion intersects removed col -> drop it
                    fusions.removeWhere((f) => f['startCol']! <= position && f['endCol']! >= position);
                    for (var f in fusions) {
                      if (f['startCol']! > position) {
                        f['startCol'] = f['startCol']! - 1;
                        f['endCol'] = f['endCol']! - 1;
                      }
                    }
                  } else {
                    // remove row at position
                    if (position < 0 || position >= rows.length) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position invalide')));
                      return;
                    }
                    rows.removeAt(position);
                    // update fusions: remove those intersecting this row
                    fusions.removeWhere((f) => f['startRow']! <= position && f['endRow']! >= position);
                    for (var f in fusions) {
                      if (f['startRow']! > position) {
                        f['startRow'] = f['startRow']! - 1;
                        f['endRow'] = f['endRow']! - 1;
                      }
                    }
                  }

                  await _firestore.collection('fiches_structures').doc(docId).update({
                    'colonnes': cols,
                    'lignes': rows,
                    'fusions': fusions,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Suppression effectuée")));
                  _chargerFiches();
                },
                child: const Text('Supprimer'),
              )
            ],
          );
        });
      },
    );
  }


  // ---------- Option 4 : Fusionner et centrer des cellules ----------
  Future<void> _fusionnerEtCentrer(Map<String, dynamic> ficheData) async {
    final docId = ficheData['id']?.toString();
    if (docId == null) return;

    List<String> cols = List<String>.from(ficheData['colonnes'] ?? []);
    List<Map<String, dynamic>> rows = (ficheData['lignes'] as List?)
        ?.map((r) => {
      'fusionner': (r as Map<String, dynamic>)['fusionner'] ?? false,
      'valeurs': List<String>.from(
        ((r as Map<String, dynamic>)['valeurs'] ?? [])
            .map((v) => v?.toString() ?? ''),
        growable: true,
      ),
    })
        .toList() ??
        [];

    List<Map<String, int>> fusions = (ficheData['fusions'] as List?)
        ?.map((f) => {
      'startRow': (f['startRow'] as num?)?.toInt() ?? 0,
      'startCol': (f['startCol'] as num?)?.toInt() ?? 0,
      'endRow': (f['endRow'] as num?)?.toInt() ?? 0,
      'endCol': (f['endCol'] as num?)?.toInt() ?? 0,
    })
        .toList() ??
        [];

    final Set<String> selected = {};

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialog) {
          final int rowCount = rows.length + 1; // +1 pour le header
          final int colCount = cols.length;

          Widget buildGrid() {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: List.generate(rowCount, (r) {
                  return Row(
                    children: List.generate(colCount, (c) {
                      final key = '$r:$c';
                      final bool isSelected = selected.contains(key);

                      final String cellValue;
                      if (r == 0) {
                        cellValue = cols[c]; // header
                      } else {
                        cellValue =
                            (rows[r - 1]['valeurs'] as List)[c]?.toString() ?? '';
                      }

                      return GestureDetector(
                        onTap: () {
                          setDialog(() {
                            if (isSelected) {
                              selected.remove(key);
                            } else {
                              selected.add(key);
                            }
                          });
                        },
                        child: Container(
                          width: 120,
                          height: 48,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.grey.shade100,
                            border: Border.all(
                              color: Colors.grey,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            cellValue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Fusionner et centrer des cellules'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Sélectionnez un bloc rectangulaire de cellules à fusionner.'),
                  const SizedBox(height: 12),
                  SizedBox(height: 300, child: buildGrid()),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selected.length < 2) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Sélectionnez au moins 2 cellules.')),
                    );
                    return;
                  }

                  // détection rectangle
                  final coords = selected.map((s) {
                    final parts = s.split(':');
                    return [int.parse(parts[0]), int.parse(parts[1])];
                  }).toList();
                  final minRow =
                  coords.map((c) => c[0]).reduce((a, b) => a < b ? a : b);
                  final maxRow =
                  coords.map((c) => c[0]).reduce((a, b) => a > b ? a : b);
                  final minCol =
                  coords.map((c) => c[1]).reduce((a, b) => a < b ? a : b);
                  final maxCol =
                  coords.map((c) => c[1]).reduce((a, b) => a > b ? a : b);

                  final expectedCount =
                      (maxRow - minRow + 1) * (maxCol - minCol + 1);
                  if (expectedCount != selected.length) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'La sélection doit être un rectangle complet.')),
                    );
                    return;
                  }

                  // 🔹 Conserver toutes les valeurs, en les concaténant
                  String mergedText = '';
                  for (int rr = minRow; rr <= maxRow; rr++) {
                    for (int cc = minCol; cc <= maxCol; cc++) {
                      final val = rr == 0
                          ? cols[cc]
                          : (rows[rr - 1]['valeurs'] as List)[cc]?.toString() ??
                          '';
                      if (val.isNotEmpty) {
                        mergedText +=
                            (mergedText.isEmpty ? '' : ' ') + val.toString();
                      }
                    }
                  }

                  // Mettre le texte fusionné dans la cellule top-left
                  if (minRow == 0) {
                    cols[minCol] = mergedText;
                  } else {
                    (rows[minRow - 1]['valeurs'] as List)[minCol] = mergedText;
                  }

                  // Vider uniquement les autres cases
                  for (int rr = minRow; rr <= maxRow; rr++) {
                    for (int cc = minCol; cc <= maxCol; cc++) {
                      if (rr == minRow && cc == minCol) continue;
                      if (rr == 0) {
                        cols[cc] = '';
                      } else {
                        (rows[rr - 1]['valeurs'] as List)[cc] = '';
                      }
                    }
                  }

                  // Sauvegarder fusion
                  fusions.add({
                    'startRow': minRow,
                    'startCol': minCol,
                    'endRow': maxRow,
                    'endCol': maxCol,
                  });

                  await _firestore
                      .collection('fiches_structures')
                      .doc(docId)
                      .update({
                    'colonnes': cols,
                    'lignes': rows,
                    'fusions': fusions,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                        content: Text('Fusion réalisée et centrée.')),
                  );
                  _chargerFiches();
                },
                child: const Text('Fusionner'),
              ),
            ],
          );
        });
      },
    );
  }
}