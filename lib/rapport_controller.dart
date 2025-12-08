import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class ControllerFillFichePage extends StatefulWidget {
  const ControllerFillFichePage({Key? key}) : super(key: key);

  @override
  State<ControllerFillFichePage> createState() => _ControllerFillFichePageState();
}

class _ControllerFillFichePageState extends State<ControllerFillFichePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _loading = true;
  List<DocumentSnapshot> _fiches = [];
  List<DocumentSnapshot> _filteredFiches = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiches();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredFiches = _fiches;
      });
    } else {
      setState(() {
        _filteredFiches = _fiches.where((fiche) {
          final data = fiche.data() as Map<String, dynamic>? ?? {};
          final sousAgence = data['sousAgence']?.toString().toLowerCase() ?? '';
          return sousAgence.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadFiches() async {
    setState(() => _loading = true);
    final snap = await _firestore.collection('fiches_structures').orderBy('sousAgence').get();
    setState(() {
      _fiches = snap.docs;
      _filteredFiches = _fiches;
      _loading = false;
    });
  }

  void _openFicheDetail(DocumentSnapshot ficheDoc) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FicheDetailPage(
          ficheDoc: ficheDoc,
          onChanged: _loadFiches,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildFicheTile(DocumentSnapshot doc, bool isTablet) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final sousAgence = data['sousAgence'] ?? 'Inconnue';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final subtitle = createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt) : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isTablet ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openFicheDetail(doc),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            child: Row(
              children: [
                Container(
                  width: isTablet ? 70 : 50,
                  height: isTablet ? 70 : 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.description_rounded,
                    color: const Color(0xFF2E7D32),
                    size: isTablet ? 28 : 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sousAgence.toString(),
                        style: TextStyle(
                          fontSize: isTablet ? 20 : 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Créée le $subtitle',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: isTablet ? 20 : 16,
                  color: const Color(0xFF2E7D32).withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFicheGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final crossAxisCount = isTablet ?
        (constraints.maxWidth > 900 ? 3 : 2) : 1;

        return GridView.builder(
          padding: EdgeInsets.symmetric(
            vertical: 16,
            horizontal: isTablet ? 24 : 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isTablet ? 2.5 : 2.0,
          ),
          itemCount: _filteredFiches.length,
          itemBuilder: (context, i) => _buildFicheTile(_filteredFiches[i], isTablet),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher une fiche...',
          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            'Fiches à remplir',
            key: ValueKey(_loading),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
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
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFiches,
            tooltip: 'Actualiser',
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
              'Chargement des fiches...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      )
          : Column(
        children: [
          if (_fiches.isNotEmpty) _buildSearchField(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _filteredFiches.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _searchController.text.isEmpty
                          ? 'Aucune fiche disponible'
                          : 'Aucun résultat trouvé',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Les fiches apparaîtront ici une fois créées'
                            : 'Essayez avec d\'autres termes de recherche',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: _loadFiches,
                color: const Color(0xFF2E7D32),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;
                    return isTablet ? _buildFicheGrid() : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: _filteredFiches.length,
                      itemBuilder: (context, i) => _buildFicheTile(_filteredFiches[i], isTablet),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FicheDetailPage extends StatefulWidget {
  final DocumentSnapshot ficheDoc;
  final VoidCallback? onChanged;

  const FicheDetailPage({Key? key, required this.ficheDoc, this.onChanged}) : super(key: key);

  @override
  State<FicheDetailPage> createState() => _FicheDetailPageState();
}

class _FicheDetailPageState extends State<FicheDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  late Map<String, dynamic> _ficheData;
  bool _loading = true;

  int? _selectedRowIndex;

  @override
  void initState() {
    super.initState();
    _loadFicheData();
  }

  // ===========================
  // ULTRA PROFESSIONAL TABLE - COMPLETELY FIXED
  // ===========================
  Widget _buildDataTable() {
    final List<String> colonnes = List<String>.from(_ficheData['colonnes'] ?? []);
    final List<Map<String, dynamic>> lignes =
    List<Map<String, dynamic>>.from(_ficheData['lignes'] ?? []);
    final List<Map<String, dynamic>> fusions =
    List<Map<String, dynamic>>.from(_ficheData['fusions'] ?? []);

    const double cellWidth = 120;
    const double cellHeight = 48;

    // ✅ Créer une grille logique pour savoir quelles cellules sont cachées
    final hiddenCells = <String>{};
    final fusionMap = <String, Map<String, int>>{};

    for (final fusion in fusions) {
      final startRow = (fusion['startRow'] as num?)?.toInt() ?? 0;
      final startCol = (fusion['startCol'] as num?)?.toInt() ?? 0;
      final endRow   = (fusion['endRow']   as num?)?.toInt() ?? startRow;
      final endCol   = (fusion['endCol']   as num?)?.toInt() ?? startCol;


      // Marquer les autres cellules comme "cachées"
      for (int r = startRow; r <= endRow; r++) {
        for (int c = startCol; c <= endCol; c++) {
          if (r == startRow && c == startCol) continue;
          hiddenCells.add('$r:$c');
        }
      }
    }

    // ✅ Générer les lignes du tableau avec fusion
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: FixedColumnWidth(cellWidth),
        border: TableBorder.all(color: Colors.grey, width: 1),
        children: [
          // --- Header ---
          TableRow(
            children: List.generate(colonnes.length, (colIndex) {
              final key = '0:$colIndex';
              if (hiddenCells.contains(key)) return const SizedBox.shrink();

              final fusion = fusionMap[key];
              int colSpan = 1;
              int rowSpan = 1;
              if (fusion != null) {
                colSpan = (fusion['endCol']! - fusion['startCol']! + 1);
                rowSpan = (fusion['endRow']! - fusion['startRow']! + 1);
              }

              return _buildMergedCell(
                cellText: colonnes[colIndex],
                width: cellWidth * colSpan,
                height: cellHeight * rowSpan,
                onEdit: null,
              );
            }),
          ),
          // --- Body ---
          ...List.generate(lignes.length, (rowIndex) {
            final rowData = lignes[rowIndex];
            final valeurs = List<String>.from(rowData['valeurs'] ?? []);
            final actualRow = rowIndex + 1; // +1 car header = ligne 0

            return TableRow(
              children: List.generate(colonnes.length, (colIndex) {
                final key = '$actualRow:$colIndex';
                if (hiddenCells.contains(key)) return const SizedBox.shrink();

                final fusion = fusionMap[key];
                int colSpan = 1;
                int rowSpan = 1;
                if (fusion != null) {
                  colSpan = (fusion['endCol']! - fusion['startCol']! + 1);
                  rowSpan = (fusion['endRow']! - fusion['startRow']! + 1);
                }

                final text = (colIndex < valeurs.length)
                    ? valeurs[colIndex]
                    : '';

                return _buildMergedCell(
                  cellText: text,
                  width: cellWidth * colSpan,
                  height: cellHeight * rowSpan,
                  onEdit: () async {
                    final controller = TextEditingController(text: text);
                    final newValue = await showDialog<String>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Modifier la cellule (${colonnes[colIndex]})'),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Entrez une valeur...',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(context, controller.text.trim()),
                            child: const Text('Enregistrer'),
                          ),
                        ],
                      ),
                    );

                    if (newValue != null && newValue != text) {
                      await _updateCellValue(rowIndex, colIndex, newValue);
                    }
                  },
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  /// 🔹 Widget de cellule fusionnée ou normale
  Widget _buildMergedCell({
    required String cellText,
    required double width,
    required double height,
    required VoidCallback? onEdit,
  }) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        color: Colors.grey.shade100,
        child: Text(
          cellText,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMergedRow({
    required int rowIndex,
    required List<String> colonnes,
    required List lignesRaw,
    required Map<String, Map<String, int>> fusionByCell,
    required bool isHeader,
    required int colCount,
    required int rowCount,
  }) {
    // rowIndex: 0 = header, 1.. = data rows (index-1 in lignesRaw)
    final double rowHeight = 60;

    final bool isSelectedRow = !isHeader && _selectedRowIndex == (rowIndex - 1);

    // Build children (cells) while skipping cells that are inside a fusion but not the top-left
    List<Widget> cells = [];
    int c = 0;
    while (c < colCount) {
      final key = '$rowIndex:$c';
      final fusion = fusionByCell[key];

      if (fusion != null) {
        final int startR = fusion['startRow']!;
        final int startC = fusion['startCol']!;
        final int endR = fusion['endRow']!;
        final int endC = fusion['endCol']!;
        final bool isTopLeft = (startR == rowIndex && startC == c);

        final int colspan = endC - startC + 1;
        final int rowspan = endR - startR + 1;

        if (isTopLeft) {
          // content for top-left: header or data
          final String content;
          if (rowIndex == 0) {
            // header top-left content
            content = colonnes[c];
          } else {
            final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[rowIndex - 1]);
            final List valeurs = List.from(ligne['valeurs'] ?? []);
            content = valeurs.isNotEmpty ? (valeurs[startC]?.toString() ?? '') : '';
          }

          // Create fused cell (visual style)
          cells.add(
            Expanded(
              flex: colspan,
              child: Container(
                height: rowHeight,
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: rowIndex == 0 ? 14 : 15,
                      fontWeight: rowIndex == 0 ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        } else {
          // cell is part of fusion but not top-left: show visually empty/disabled cell
          cells.add(
            Expanded(
              flex: 1,
              child: Container(
                height: rowHeight,
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.06),
                  border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.4), width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          );
        }

        // Advance by colspan
        c = endC + 1;
      } else {
        // Normal cell (not part of any fusion)
        final String content;
        if (rowIndex == 0) {
          content = colonnes[c];
        } else {
          final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[rowIndex - 1]);
          final List valeurs = List.from(ligne['valeurs'] ?? []);
          content = (c < valeurs.length) ? (valeurs[c]?.toString() ?? '') : '';
        }

        // Render editable cell (click to edit)
        Widget cellWidget = GestureDetector(
          onTap: () async {
            if (rowIndex == 0) {
              // header click - do nothing or maybe future feature
              return;
            }
            // Only allow editing if creator is current user (as before)
            final int dataRowIndex = rowIndex - 1;
            final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[dataRowIndex]);
            final creatorUid = ligne['creatorUid']?.toString() ?? '';
            if (creatorUid != (_currentUser?.uid ?? '')) {
              // show not authorized dialog
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Modification non autorisée'),
                  content: Text("Désolé ! cette cellule appartient à un contrôleur différent (${ligne['creatorName'] ?? 'Inconnu'})."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                  ],
                ),
              );
              return;
            }

            final controller = TextEditingController(text: content);
            final newValue = await showDialog<String>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('Modifier la cellule (${colonnes[c]})'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Entrez une valeur...',
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            );

            if (newValue != null && newValue != content) {
              await _updateCellValue(rowIndex - 1, c, newValue);
            }
          },
          child: Container(
            height: rowHeight,
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isHeader ? const Color(0xFF2E7D32).withOpacity(0.06) : Theme.of(context).colorScheme.background,
              border: Border(
                right: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
                top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.08)),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: isHeader ? 14 : 14,
                  fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

        cells.add(Expanded(child: cellWidget));
        c++;
      }
    }

    // Add actions column (fixed width)
    cells.add(
      SizedBox(
        width: 100,
        child: Container(
          height: rowHeight,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isHeader)
                Builder(builder: (context) {
                  final int dataIndex = rowIndex - 1;
                  final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[dataIndex]);
                  final creatorUid = ligne['creatorUid']?.toString() ?? '';
                  final isOwnedByCurrentUser = creatorUid == (_currentUser?.uid ?? '');
                  if (isOwnedByCurrentUser) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2E7D32)),
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => _selectedRowIndex = dataIndex);
                              _onEditLine();
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                          onPressed: () {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() => _selectedRowIndex = dataIndex);
                              _onDeleteLine();
                            });
                          },
                        ),
                      ],
                    );
                  } else {
                    return const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey);
                  }
                })
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: () {
        if (!isHeader) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedRowIndex = rowIndex - 1);
          });
        }
      },
      child: Container(
        color: isSelectedRow ? const Color(0xFF2E7D32).withOpacity(0.04) : Theme.of(context).colorScheme.surface,
        child: Row(
          children: cells,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.table_rows_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune donnée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des lignes pour les voir apparaître ici',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================
  // Utilities to update the doc
  // ===========================
  Future<void> _updateLignesAtomically(List<Map<String, dynamic>> newLignes) async {
    await _firestore.runTransaction((tx) async {
      final docSnap = await tx.get(widget.ficheDoc.reference);
      if (!docSnap.exists) throw 'Fiche supprimée';
      tx.update(widget.ficheDoc.reference, {'lignes': newLignes, 'updatedAt': FieldValue.serverTimestamp()});
    });
    await _loadFicheData();
    widget.onChanged?.call();
  }

  Future<void> _updateCellValue(int rowIndex, int colIndex, String newValue) async {
    final List lignesRaw = List.from(_ficheData['lignes'] ?? []);
    if (rowIndex < 0 || rowIndex >= lignesRaw.length) return;

    final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[rowIndex]);
    final List valeurs = List.from(ligne['valeurs'] ?? []);

    // ensure length
    while (valeurs.length <= colIndex) {
      valeurs.add('');
    }

    valeurs[colIndex] = newValue;
    ligne['valeurs'] = valeurs;
    ligne['updatedAt'] = DateTime.now().toIso8601String();

    lignesRaw[rowIndex] = ligne;

    await _updateLignesAtomically(lignesRaw.map((e) => Map<String, dynamic>.from(e)).toList());
  }

  Future<void> _loadFicheData() async {
    setState(() => _loading = true);
    final fresh = await widget.ficheDoc.reference.get();
    setState(() {
      _ficheData = (fresh.data() as Map<String, dynamic>?) ?? {};
      _loading = false;
      _selectedRowIndex = null;
    });
  }

  // ===========================
  // Add line (adds empty line WITHOUT form)
  // ===========================
  Future<void> _onAddLine() async {
    final List<String> colonnes = List<String>.from(_ficheData['colonnes'] ?? []);
    if (colonnes.isEmpty) {
      _showSnackBar(
        'Cette fiche n\'a pas de colonnes.',
        Icons.warning_amber_rounded,
        Colors.orange,
      );
      return;
    }

    final uniqueId = const Uuid().v4();
    final newLine = {
      'idTemp': uniqueId,
      'fusionner': false,
      'valeurs': List.filled(colonnes.length, ''), // ligne vide
      'creatorUid': _currentUser?.uid ?? 'unknown',
      'creatorName': _currentUser?.displayName ?? _currentUser?.email ?? '',
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      await _firestore.runTransaction((tx) async {
        final docSnap = await tx.get(widget.ficheDoc.reference);
        if (!docSnap.exists) throw Exception('Fiche introuvable');

        final data = docSnap.data() as Map<String, dynamic>? ?? {};
        final lignes = List<Map<String, dynamic>>.from(data['lignes'] ?? []);
        lignes.add(newLine);

        tx.update(widget.ficheDoc.reference, {
          'lignes': lignes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _loadFicheData();
      _showSnackBar(
        'Nouvelle ligne ajoutée. Cliquez sur une cellule pour saisir les données.',
        Icons.info_outline,
        Colors.blue,
      );
    } catch (e) {
      debugPrint("Erreur Firestore (ajout ligne): $e");
      _showSnackBar(
        'Erreur lors de l\'ajout : $e',
        Icons.error_rounded,
        Colors.red[700]!,
      );
    }
  }

  // ===========================
  // Edit line
  // ===========================
  Future<void> _onEditLine() async {
    final int? idx = _selectedRowIndex;
    if (idx == null) {
      _showSnackBar(
        'Sélectionnez d\'abord une ligne.',
        Icons.info_rounded,
        Colors.orange,
      );
      return;
    }

    final List lignesRaw = List.from(_ficheData['lignes'] ?? []);
    if (idx < 0 || idx >= lignesRaw.length) return;

    final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[idx]);
    final creatorUid = ligne['creatorUid']?.toString() ?? '';
    final creatorName = ligne['creatorName']?.toString() ?? 'Inconnu';

    if (creatorUid != (_currentUser?.uid ?? '')) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Modification non autorisée'),
          content: Text(
            "Désolé ! cette ligne a été ajoutée par le contrôleur '$creatorName'. Vous ne pouvez pas la modifier.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final bool fusion = ligne['fusionner'] == true ||
        (ligne['valeurs'] is List && (ligne['valeurs'] as List).length == 1);
    final List<String> existingValues = fusion
        ? [
      (ligne['valeurs'] is List && (ligne['valeurs'] as List).isNotEmpty)
          ? (ligne['valeurs'] as List).first.toString()
          : ''
    ]
        : List<String>.from(
      ligne['valeurs'].map((e) => e?.toString() ?? ''),
    );

    final colonnes = List<String>.from(_ficheData['colonnes'] ?? []);

    final result = await showDialog<_LineEditResult>(
      context: context,
      builder: (context) => LineEditDialog(
        colonnes: colonnes,
        initialValues: existingValues,
        fusionInitial: fusion,
        title: 'Modifier la ligne',
      ),
    );

    if (result == null) return;

    try {
      await _firestore.runTransaction((tx) async {
        final docSnap = await tx.get(widget.ficheDoc.reference);
        if (!docSnap.exists) throw Exception('Fiche introuvable');

        final data = docSnap.data() as Map<String, dynamic>? ?? {};
        final List current = List.from(data['lignes'] ?? []);

        if (idx < 0 || idx >= current.length) return;

        final Map<String, dynamic> updatedLine = {
          ...Map<String, dynamic>.from(current[idx]),
          'fusionner': result.fusion,
          'valeurs': result.fusion ? [result.values.first] : result.values,
          'updatedAt': DateTime.now().toIso8601String(),
          'editorUid': _currentUser?.uid ?? '',
          'editorName':
          _currentUser?.displayName ?? _currentUser?.email ?? '',
        };

        current[idx] = updatedLine;

        tx.update(widget.ficheDoc.reference, {
          'lignes': current,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      await _loadFicheData();
      _showSnackBar(
        'Ligne modifiée avec succès.',
        Icons.check_circle_rounded,
        const Color(0xFF2E7D32),
      );
    } catch (e) {
      debugPrint("Erreur Firestore (modif): $e");
      _showSnackBar(
        'Erreur lors de la modification : $e',
        Icons.error_rounded,
        Colors.red[700]!,
      );
    }
  }

  // ===========================
  // Delete line
  // ===========================
  Future<void> _onDeleteLine() async {
    final int? idx = _selectedRowIndex;
    if (idx == null) {
      _showSnackBar(
        'Sélectionnez d\'abord une ligne.',
        Icons.info_rounded,
        Colors.orange,
      );
      return;
    }

    final List lignesRaw = List.from(_ficheData['lignes'] ?? []);
    if (idx < 0 || idx >= lignesRaw.length) return;

    final Map<String, dynamic> ligne = Map<String, dynamic>.from(lignesRaw[idx]);
    final creatorUid = ligne['creatorUid']?.toString() ?? '';
    final creatorName = ligne['creatorName']?.toString() ?? 'Inconnu';

    if (creatorUid != (_currentUser?.uid ?? '')) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Suppression non autorisée'),
          content: Text("Désolé ! cette ligne a été ajoutée par le contrôleur '$creatorName'. Vous ne pouvez pas supprimer cette ligne."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la ligne'),
        content: const Text('Voulez-vous vraiment supprimer cette ligne ? Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestore.runTransaction((tx) async {
      final docSnap = await tx.get(widget.ficheDoc.reference);
      if (!docSnap.exists) throw 'Fiche introuvable';
      final Map<String, dynamic> data = docSnap.data() as Map<String, dynamic>;
      final List current = List.from(data['lignes'] ?? []);
      if (idx >= 0 && idx < current.length) {
        current.removeAt(idx);
        tx.update(widget.ficheDoc.reference, {'lignes': current, 'updatedAt': FieldValue.serverTimestamp()});
      }
    });

    await _loadFicheData();
    _showSnackBar(
      'Ligne supprimée avec succès.',
      Icons.check_circle_rounded,
      const Color(0xFF2E7D32),
    );
  }

  void _showSnackBar(String message, IconData icon, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildRowCard(int index, Map<String, dynamic> ligne) {
    final fusion = ligne['fusionner'] == true;
    final valeurs = (ligne['valeurs'] as List).map((e) => e?.toString() ?? '').toList();
    final creatorName = ligne['creatorName']?.toString() ?? 'Inconnu';
    final createdAt = (ligne['createdAt'] is Timestamp) ? (ligne['createdAt'] as Timestamp).toDate() : null;

    final bool isSelected = _selectedRowIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2E7D32).withOpacity(0.08) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: const Color(0xFF2E7D32), width: 2)
            : Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedRowIndex = index),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    Expanded(
                      child: fusion
                          ? Center(
                        child: Text(
                          valeurs.isNotEmpty ? valeurs[0] : '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                          : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 400;
                          return isWide
                              ? Row(
                            children: valeurs.map((v) {
                              return Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.background,
                                    border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    v,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                              : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: valeurs.map((v) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.background,
                                  border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  v,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        const SizedBox(width: 6),
                        Text(
                          'Par: $creatorName',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                        ),
                      ],
                    ),
                    if (createdAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedRowIndex != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 10),
                  Text(
                    'Ligne ${_selectedRowIndex! + 1} sélectionnée',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _onAddLine,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Ajouter une ligne'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (_selectedRowIndex != null) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _onEditLine,
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text('Modifier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    side: BorderSide(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _onDeleteLine,
                  icon: const Icon(Icons.delete, size: 20),
                  label: const Text('Supprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Chargement...'),
            backgroundColor: const Color(0xFF2E7D32)
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              ),
              SizedBox(height: 16),
              Text(
                'Chargement de la fiche...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final sousAgence = _ficheData['sousAgence'] ?? 'Inconnue';
    final List<String> colonnes = List<String>.from(_ficheData['colonnes'] ?? []);
    final List lignesRaw = List.from(_ficheData['lignes'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fiche: $sousAgence',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        toolbarHeight: 80,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFicheData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Actions buttons
          _buildActionButtons(),
          const SizedBox(height: 16),

          // Table header avec informations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Tableau de données',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "${colonnes.length} colonne${colonnes.length != 1 ? 's' : ''} • ${lignesRaw.length} ligne${lignesRaw.length != 1 ? 's' : ''}",
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tableau principal - PREND TOUT L'ESPACE RESTANT
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildDataTable(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ===========================
// Dialog widget to add/edit a line
// ===========================
class LineEditDialog extends StatefulWidget {
  final List<String> colonnes;
  final List<String>? initialValues;
  final bool fusionInitial;
  final String title;

  const LineEditDialog({
    Key? key,
    required this.colonnes,
    this.initialValues,
    this.fusionInitial = false,
    this.title = 'Éditer la ligne',
  }) : super(key: key);

  @override
  _LineEditDialogState createState() => _LineEditDialogState();
}

class _LineEditDialogState extends State<LineEditDialog> {
  late bool _fusion;
  late List<TextEditingController> _controllers;
  late TextEditingController _fusionController;

  @override
  void initState() {
    super.initState();
    _fusion = widget.fusionInitial;
    _controllers = [];
    _fusionController = TextEditingController();

    if (_fusion) {
      _fusionController = TextEditingController(text: widget.initialValues?.first ?? '');
    } else {
      _controllers = List.generate(
          widget.colonnes.length,
              (i) => TextEditingController(
              text: widget.initialValues != null && i < widget.initialValues!.length
                  ? widget.initialValues![i]
                  : ''
          )
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _fusionController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (_fusion) {
      final value = _fusionController.text.trim();
      if (value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entrez une valeur pour la ligne fusionnée.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
        return;
      }
      Navigator.pop(context, _LineEditResult(fusion: true, values: [value]));
    } else {
      final values = _controllers.map((c) => c.text.trim()).toList();
      if (values.every((v) => v.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remplissez au moins une cellule.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        );
        return;
      }
      Navigator.pop(context, _LineEditResult(fusion: false, values: values));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fusionner et centrer les cellules (une valeur)'),
              value: _fusion,
              onChanged: (v) => setState(() => _fusion = v ?? false),
            ),
            const SizedBox(height: 16),
            if (_fusion)
              TextField(
                controller: _fusionController,
                decoration: const InputDecoration(
                  labelText: 'Valeur fusionnée',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                maxLines: 3,
              )
            else
              Wrap(
                runSpacing: 16,
                spacing: 16,
                children: List.generate(widget.colonnes.length, (i) {
                  return SizedBox(
                    width: isNarrow ? double.infinity : 220,
                    child: TextField(
                      controller: _controllers[i],
                      decoration: InputDecoration(
                        labelText: widget.colonnes[i],
                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annuler')
        ),
        ElevatedButton(
          onPressed: _onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _LineEditResult {
  final bool fusion;
  final List<String> values;
  _LineEditResult({required this.fusion, required this.values});
}
