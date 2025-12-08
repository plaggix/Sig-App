import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/ia_service.dart';

class TendancesPage extends StatefulWidget {
  @override
  _TendancesPageState createState() => _TendancesPageState();
}

class _TendancesPageState extends State<TendancesPage>
    with TickerProviderStateMixin {
  Map<String, dynamic>? resultats;
  bool loading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  ColorScheme get _colorScheme => ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    brightness: Theme.of(context).brightness,
  );

  static const double _cardRadius = 16.0;
  static const double _elementSpacing = 16.0;
  static const Duration _animationDuration = Duration(milliseconds: 500);

  final List<Color> _chartColors = [
    const Color(0xFF2E7D32),
    const Color(0xFF4CAF50),
    const Color(0xFF8BC34A),
    const Color(0xFFCDDC39),
    const Color(0xFF607D8B),
    const Color(0xFF795548),
    const Color(0xFF2196F3),
    const Color(0xFFFF9800),
    const Color(0xFFF44336),
    const Color(0xFF9C27B0),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(duration: _animationDuration, vsync: this);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _chargerTendances().then((_) {
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _chargerTendances() async {
    final data = await analyserTendances();
    setState(() {
      resultats = data;
      loading = false;
    });
  }

  Widget _buildLoadingSkeleton() {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isLargeScreen ? 2 : 1,
      crossAxisSpacing: _elementSpacing,
      mainAxisSpacing: _elementSpacing,
      children: List.generate(3, (index) {
        return Container(
          decoration: BoxDecoration(
            color: _colorScheme.surface,
            borderRadius: BorderRadius.circular(_cardRadius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: _colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 80,
            color: _colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Pas encore de tendances disponibles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les données de tendances apparaîtront ici',
            style: TextStyle(color: _colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _chargerTendances,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget chart,
    required Widget legend,
    bool showExpandButton = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius)),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: _colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: isCompact ? 13 : 14,
                              color: _colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showExpandButton)
                      IconButton(
                        icon: Icon(Icons.expand_more,
                            color: _colorScheme.primary),
                        onPressed: () {},
                      ),
                  ],
                ),
                SizedBox(height: isCompact ? 12 : 20),
                chart,
                SizedBox(height: isCompact ? 12 : 16),
                legend,
              ],
            ),
          ),
        );
      },
    );
  }

  // --- les méthodes _buildBarChart, _buildPieChart, etc. ne changent pas ---

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final basePadding = isMobile ? 12.0 : 20.0;
    final baseSpacing = isMobile ? 12.0 : 16.0;
    final isLargeScreen = size.width > 600;

    return Scaffold(
      backgroundColor: _colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Tendances IA',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        backgroundColor: _colorScheme.primary,
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        toolbarHeight: isMobile ? 70 : 90,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _chargerTendances,
            tooltip: 'Actualiser les tendances',
          ),
        ],
      ),
      body: loading
          ? _buildLoadingSkeleton()
          : resultats == null
          ? _buildEmptyState()
          : AnimatedBuilder(
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
          padding: EdgeInsets.all(basePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Analyses et Tendances",
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  color: _colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Données analysées par intelligence artificielle",
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: _colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: baseSpacing * 2),

              // --- Grille responsive ---
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth > 1000
                      ? 3
                      : constraints.maxWidth > 700
                      ? 2
                      : 1;
                  final ratio =
                  constraints.maxWidth > 700 ? 1.2 : 1.4;

                  return GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: baseSpacing,
                      mainAxisSpacing: baseSpacing,
                      childAspectRatio: ratio,
                    ),
                    children: [
                      _buildChartCard(
                        title: "Taux d'inachèvement par entreprise",
                        subtitle:
                        "Pourcentage de tâches non terminées",
                        chart: SizedBox(
                          height: isMobile ? 180 : 240,
                          child: _buildBarChart(
                            resultats!["statsEntreprises"]
                            as Map<String, dynamic>,
                          ),
                        ),
                        legend: _buildBarChartLegend(
                          resultats!["statsEntreprises"]
                          as Map<String, dynamic>,
                          false,
                        ),
                      ),
                      _buildChartCard(
                        title: "Tâches inachevées par contrôleur",
                        subtitle: "Nombre de tâches non terminées",
                        chart: SizedBox(
                          height: isMobile ? 180 : 240,
                          child: _buildBarChart(
                            resultats!["statsControleurs"]
                            as Map<String, dynamic>,
                            isControleur: true,
                          ),
                        ),
                        legend: _buildBarChartLegend(
                          resultats!["statsControleurs"]
                          as Map<String, dynamic>,
                          true,
                        ),
                      ),
                      _buildChartCard(
                        title:
                        "Mots-clés fréquents dans les rapports",
                        subtitle:
                        "Répartition des termes les plus utilisés",
                        chart: SizedBox(
                          height: isMobile ? 220 : 300,
                          child: _buildPieChart(
                            resultats!["motsCles"]
                            as Map<String, int>,
                          ),
                        ),
                        legend: _buildPieChartLegend(
                          resultats!["motsCles"]
                          as Map<String, int>,
                        ),
                        showExpandButton: true,
                      ),
                    ],
                  );
                },
              ),

              SizedBox(height: baseSpacing * 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> data, {bool isControleur = false}) {
    final keys = data.keys.toList();
    final values = keys.map((k) {
      final total = data[k]["total"];
      final inach = data[k]["inacheves"];
      return isControleur ? inach : (total > 0 ? ((inach / total) * 100).round() : 0);
    }).toList();

    final maxValue = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b).toDouble() : 100.0;

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: _colorScheme.surface,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY;
              final label = keys[groupIndex];
              return BarTooltipItem(
                isControleur
                    ? '$label\n$value tâches inachevées'
                    : '$label\n${value.toStringAsFixed(1)}% d\'inachèvement',
                TextStyle(
                  color: _colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue > 0 ? maxValue / 5 : 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _colorScheme.outline.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: maxValue > 0 ? maxValue / 5 : 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: _colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < keys.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      keys[value.toInt()],
                      style: TextStyle(
                        fontSize: 10,
                        color: _colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: List.generate(keys.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i].toDouble(),
                color: _chartColors[i % _chartColors.length],
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> motsCles) {
    final top5 = motsCles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final limited = top5.take(5).toList();
    final total = limited.fold<int>(0, (sum, item) => sum + item.value);

    int touchedIndex = -1;

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                touchedIndex = -1;
                return;
              }
              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: limited.map((e) {
          final index = limited.indexOf(e);
          final isTouched = index == touchedIndex;
          final radius = isTouched ? 90.0 : 80.0;
          final pourcentage = total > 0 ? (e.value / total * 100) : 0;

          return PieChartSectionData(
            value: e.value.toDouble(),
            title: pourcentage > 5 ? '${pourcentage.toStringAsFixed(1)}%' : '',
            radius: radius,
            color: _chartColors[index % _chartColors.length],
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _colorScheme.onPrimary,
            ),
            titlePositionPercentageOffset: 0.6,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPieChartLegend(Map<String, int> motsCles) {
    final top5 = motsCles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final limited = top5.take(5).toList();
    final total = limited.fold<int>(0, (sum, item) => sum + item.value);

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: limited.map((e) {
        final index = limited.indexOf(e);
        final pourcentage = total > 0 ? (e.value / total * 100) : 0;

        return Chip(
          label: Text('${e.key} (${pourcentage.toStringAsFixed(1)}%)'),
          backgroundColor: _chartColors[index % _chartColors.length].withOpacity(0.2),
          labelStyle: TextStyle(
            fontSize: 12,
            color: _colorScheme.onSurface,
          ),
          avatar: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _chartColors[index % _chartColors.length],
              shape: BoxShape.circle,
            ),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildBarChartLegend(Map<String, dynamic> data, bool isControleur) {
    final keys = data.keys.toList().take(5); // Limiter à 5 éléments pour la légende

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: keys.map((key) {
        final index = keys.toList().indexOf(key);
        final value = data[key];
        final total = value["total"];
        final inach = value["inacheves"];
        final displayValue = isControleur ? inach : (total > 0 ? ((inach / total) * 100).round() : 0);

        return Chip(
          label: Text('$key: $displayValue${isControleur ? '' : '%'}'),
          backgroundColor: _chartColors[index % _chartColors.length].withOpacity(0.2),
          labelStyle: TextStyle(
            fontSize: 12,
            color: _colorScheme.onSurface,
          ),
          avatar: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _chartColors[index % _chartColors.length],
              shape: BoxShape.circle,
            ),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

}
