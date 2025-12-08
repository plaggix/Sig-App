import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/ia_service.dart';

class AccueilPage extends StatefulWidget {
  const AccueilPage({super.key});

  @override
  State<AccueilPage> createState() => _AccueilPageState();
}

class _AccueilPageState extends State<AccueilPage> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _controleursActifs = 0;
  int _tachesTotales = 0;
  int _tachesTerminees = 0;
  double _tauxConformite = 0.0;
  List<String> _alertesIA = [];

  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Design System
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Color(0xFF8BC34A);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  static const double cardRadius = 16.0;
  static const double elementSpacing = 16.0;
  static const double sectionSpacing = 28.0;

  // Palette de couleurs pour les graphiques
  static const List<Color> chartColors = [
    Color(0xFF2E7D32),
    Color(0xFF4CAF50),
    Color(0xFF8BC34A),
    Color(0xFFCDDC39),
    Color(0xFF607D8B),
    Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _chargerDonnees().then((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _loading = true);

    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    // Contrôleurs actifs aujourd'hui
    final actifsSnap = await _firestore
        .collection('plannings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .get();
    final actifs = actifsSnap.docs.map((d) => d.data()['controleurId']).toSet().length;

    // Tâches totales et terminées
    final tachesSnap = await _firestore.collection('plannings').get();
    final total = tachesSnap.size;
    final terminees = tachesSnap.docs.where((d) => (d.data()['effectue'] ?? false) == true).length;

    // Taux conformité
    int conformes = tachesSnap.docs.where((d) {
      final data = d.data();
      if ((data['effectue'] ?? false) != true) return false;
      if (data['date'] == null) return false;
      final dueDate = (data['date'] as Timestamp).toDate();
      return dueDate.isBefore(DateTime.now().add(const Duration(days: 1)));
    }).length;

    double taux = total > 0 ? (conformes / total * 100).toDouble() : 0.0;

    // Insights IA
    List<String> alertes = [];
    try {
      final resultatsIA = await analyserTendances();
      alertes = List<String>.from(resultatsIA?['alertes'] ?? []);
    } catch (e) {
      alertes = ['Impossibilité de charger les insights IA pour le moment'];
    }

    setState(() {
      _controleursActifs = actifs;
      _tachesTotales = total;
      _tachesTerminees = terminees;
      _tauxConformite = taux;
      _alertesIA = alertes;
      _loading = false;
    });
  }

  Widget _buildAnimatedNumber(int value) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        value.toString(),
        key: ValueKey<int>(value),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
      ),
    );
  }

  Widget _buildAnimatedPercentage(double value) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: Text(
        '${value.toStringAsFixed(1)}%',
        key: ValueKey<double>(value),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
      ),
    );
  }

  Widget _buildStatCard(String title, Widget valueWidget, IconData icon, Color color, {List<double>? sparklineData}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (sparklineData != null && sparklineData.length > 1)
                SizedBox(
                  width: 60,
                  height: 20,
                  child: CustomPaint(
                    painter: _SparklinePainter(data: sparklineData, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          valueWidget,
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[
      FlSpot(0, 2.0),
      FlSpot(1, 3.5),
      FlSpot(2, 4.0),
      FlSpot(3, 6.0),
      FlSpot(4, 5.0),
      FlSpot(5, 8.0),
      FlSpot(6, 7.0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[300],
            strokeWidth: 1,
            dashArray: [4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 2,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final labels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
                final idx = value.toInt();
                if (idx >= 0 && idx < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(labels[idx], style: const TextStyle(fontSize: 11, color: textSecondary)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [primaryColor.withOpacity(0.3), primaryColor.withOpacity(0.1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: surfaceColor,
            tooltipRoundedRadius: cardRadius,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  spot.y.toStringAsFixed(1),
                  const TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, int> data) {
    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: entries.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                final pct = total > 0 ? (e.value / total * 100) : 0;
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  title: '',
                  color: chartColors[idx % chartColors.length],
                  radius: 60,
                  showTitle: false,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {},
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((entry) {
              final idx = entry.key;
              final e = entry.value;
              final pct = total > 0 ? (e.value / total * 100) : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: chartColors[idx % chartColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 768;

    if (_loading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                'Chargement des données...',
                style: TextStyle(color: textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Tableau de Bord',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _chargerDonnees,
        color: primaryColor,
        displacement: 40,
        child: AnimatedBuilder(
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
            padding: const EdgeInsets.all(elementSpacing),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grille responsive des statistiques
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 1000 ? 4 :
                    constraints.maxWidth > 600 ? 2 : 1;
                    return GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: columns,
                      childAspectRatio: isLargeScreen ? 1.2 : 1.5,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: elementSpacing,
                      mainAxisSpacing: elementSpacing,
                      children: [
                        _buildStatCard(
                          'Contrôleurs actifs',
                          _buildAnimatedNumber(_controleursActifs),
                          Icons.group_rounded,
                          infoColor,
                          sparklineData: [2, 3, 4, 5, 4, 6, _controleursActifs.toDouble()],
                        ),
                        _buildStatCard(
                          'Tâches totales',
                          _buildAnimatedNumber(_tachesTotales),
                          Icons.task_alt_rounded,
                          warningColor,
                          sparklineData: [10, 12, 15, 18, 20, 22, _tachesTotales.toDouble()],
                        ),
                        _buildStatCard(
                          'Terminées',
                          _buildAnimatedNumber(_tachesTerminees),
                          Icons.check_circle_rounded,
                          successColor,
                          sparklineData: [5, 7, 9, 11, 13, 15, _tachesTerminees.toDouble()],
                        ),
                        _buildStatCard(
                          'Conformité',
                          _buildAnimatedPercentage(_tauxConformite),
                          Icons.trending_up_rounded,
                          primaryColor,
                          sparklineData: [60, 65, 70, 75, 80, 85, _tauxConformite],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: sectionSpacing),

                // Section graphique de progression
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(elementSpacing),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progression hebdomadaire',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: _buildLineChart(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: sectionSpacing),

                // Section répartition par sous-agences
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(elementSpacing),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Répartition des tâches par sous-agences',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: _buildPieChart({
                          'Sud': 12,
                          'Nord': 8,
                          'Est': 5,
                          'Ouest': 3,
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: sectionSpacing),

                // Section insights IA
                if (_alertesIA.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(elementSpacing),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(cardRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.insights_rounded, color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Insights IA',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._alertesIA.map((a) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: errorColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: errorColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: errorColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  a,
                                  style: const TextStyle(fontSize: 14, color: textPrimary),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: sectionSpacing),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Peintre pour les mini graphiques sparkline
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minValue = data.reduce((a, b) => a < b ? a : b);
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final scaleY = range > 0 ? size.height / range : 1.0;
    final stepX = size.width / (data.length - 1);

    final path = Path();
    path.moveTo(0, size.height - (data[0] - minValue) * scaleY);

    for (int i = 1; i < data.length; i++) {
      path.lineTo(i * stepX, size.height - (data[i] - minValue) * scaleY);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}