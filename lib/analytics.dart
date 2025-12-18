import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'services/history_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() {
      _isLoading = false;
    });
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Analytics...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStatsCards(),
              const SizedBox(height: 32),
              _buildChartSection(),
              const SizedBox(height: 32),
              _buildConfidenceBarChart(),
              const SizedBox(height: 24),
              _buildConfusionMatrix(),
              const SizedBox(height: 32),
              _buildTopCategories(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBarChart() {
    final records = HistoryService.instance.getAll();

    // Map category -> { 'max': double, 'count': int }
    final Map<String, Map<String, dynamic>> agg = {};

    for (final r in records) {
      final cat = (r['category'] as String? ?? 'Unknown').toString();
      final conf = (r['confidence'] as double? ?? 0.0);
      final entry = agg.putIfAbsent(cat, () => {'max': 0.0, 'count': 0});
      entry['count'] = (entry['count'] as int) + 1;
      if (conf > (entry['max'] as double)) entry['max'] = conf;
    }

    if (agg.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Highest Confidence per Class',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No classifications yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Prepare data lists
    final labels = agg.keys.toList();
    final maxConfs = labels.map((k) => (agg[k]!['max'] as double) * 100).toList();
    final counts = labels.map((k) => agg[k]!['count'] as int).toList();

    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Highest Confidence per Class',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0, left: 12.0, bottom: 8.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = labels[group.x.toInt()];
                        final cnt = counts[group.x.toInt()];
                        return BarTooltipItem(
                          '$label\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: '${rod.toY.toStringAsFixed(1)}% - $cnt times',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          final text = labels[idx];
                          final short = text.length > 8 ? '${text.substring(0, 8)}...' : text;
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              short,
                              style: TextStyle(color: Colors.grey[700], fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: TextStyle(color: Colors.grey[600], fontSize: 11));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(labels.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: maxConfs[i],
                          color: colors[i % colors.length],
                          width: 18,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your classification performance and statistics',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    final stats = HistoryService.instance.getStats();
    final total = stats['total'] as int;
    final avgConfidence = stats['avgConfidence'] as double;
    final accuracyPercent = (avgConfidence * 100).toStringAsFixed(1);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Classifications',
            '$total',
            Icons.analytics_outlined,
            const Color(0xFF6366F1),
            total > 0 ? '+${total}' : '0',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Avg Confidence',
            '$accuracyPercent%',
            Icons.verified_outlined,
            const Color(0xFF10B981),
            '+${(avgConfidence * 10).toStringAsFixed(1)}%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    color: const Color(0xFF10B981),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Classification Trends',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 7 days activity',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 20,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        return Text(
                          days[value.toInt()],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateChartSpots(),
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6366F1).withOpacity(0.3),
                          const Color(0xFF8B5CF6).withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateChartSpots() {
    final records = HistoryService.instance.getAll();
    final now = DateTime.now();
    
    // Initialize counts for last 7 days
    final dayCounts = <int, int>{}; // day index (0-6) -> count
    for (int i = 0; i < 7; i++) {
      dayCounts[i] = 0;
    }
    
    // Count records by day
    for (final record in records) {
      final timestamp = record['timestamp'] as DateTime;
      final difference = now.difference(timestamp);
      final daysAgo = difference.inDays;
      
      if (daysAgo >= 0 && daysAgo < 7) {
        final dayIndex = 6 - daysAgo; // Reverse so today is 6, yesterday is 5, etc.
        dayCounts[dayIndex] = (dayCounts[dayIndex] ?? 0) + 1;
      }
    }
    
    // Generate spots
    return List.generate(7, (index) {
      return FlSpot(index.toDouble(), (dayCounts[index] ?? 0).toDouble());
    });
  }

  Widget _buildConfusionMatrix() {
    final records = HistoryService.instance.getAll();

    // Collect labels from trueLabel and predicted category
    final Set<String> labelsSet = {};
    final List<Map<String, dynamic>> withTruth = [];

    for (final r in records) {
      final trueLabel = (r['trueLabel'] as String?)?.toString();
      final pred = (r['category'] as String?)?.toString() ?? 'Unknown';
      if (trueLabel != null && trueLabel.trim().isNotEmpty) {
        labelsSet.add(trueLabel);
        labelsSet.add(pred);
        withTruth.add({'true': trueLabel, 'pred': pred});
      }
    }

    final labels = labelsSet.toList()..sort();
    if (labels.isEmpty) {
      // No explicit true labels found. Fall back to using predicted categories
      // so users still see a matrix (diagonal counts). Inform the user.
      final predictedSet = <String>{};
      for (final r in records) {
        final p = (r['category'] as String?)?.toString() ?? 'Unknown';
        if (p.trim().isNotEmpty) predictedSet.add(p);
      }
      final fallbackLabels = predictedSet.toList()..sort();

      if (fallbackLabels.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confusion Matrix',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'No classifications yet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        );
      }

      // Build simple diagonal matrix from predicted labels counts
      final idxMap2 = <String, int>{};
      for (var i = 0; i < fallbackLabels.length; i++) idxMap2[fallbackLabels[i]] = i;
      final matrix2 = List.generate(fallbackLabels.length, (_) => List<int>.filled(fallbackLabels.length, 0));
      int maxCount2 = 0;
      for (final r in records) {
        final p = (r['category'] as String?)?.toString() ?? 'Unknown';
        final pi = idxMap2[p]!;
        matrix2[pi][pi] += 1;
        if (matrix2[pi][pi] > maxCount2) maxCount2 = matrix2[pi][pi];
      }

      // Render fallback matrix with a small note
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'Confusion Matrix',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                // 'No ground-truth labels found — displaying predicted label counts on the diagonal. Use History → item → Set True Label to populate a true confusion matrix.',
                '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 120, child: Text('')),
                      ...fallbackLabels.map((l) => Container(
                            width: 72,
                            padding: const EdgeInsets.all(6),
                            alignment: Alignment.center,
                            child: Text(l, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(fallbackLabels.length, (r) {
                    final lab = fallbackLabels[r];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          padding: const EdgeInsets.all(6),
                          child: Text(lab, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                        ),
                        ...List.generate(fallbackLabels.length, (c) {
                          final count = matrix2[r][c];
                          final intensity = maxCount2 > 0 ? (count / maxCount2) : 0.0;
                          final bg = Color.lerp(Colors.white, const Color(0xFF6366F1).withOpacity(0.9), intensity)!;
                          return Tooltip(
                            message: '${fallbackLabels[r]} → ${fallbackLabels[c]}: $count',
                            child: Container(
                              width: 72,
                              height: 48,
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.withOpacity(0.12)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: intensity > 0.5 ? Colors.white : Colors.grey[800],
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final idxMap = <String, int>{};
    for (var i = 0; i < labels.length; i++) idxMap[labels[i]] = i;

    // initialize matrix
    final matrix = List.generate(labels.length, (_) => List<int>.filled(labels.length, 0));
    int maxCount = 0;
    for (final e in withTruth) {
      final t = e['true'] as String;
      final p = e['pred'] as String;
      final ti = idxMap[t]!;
      final pi = idxMap[p]!;
      matrix[ti][pi] += 1;
      if (matrix[ti][pi] > maxCount) maxCount = matrix[ti][pi];
    }

    // Build UI table-like matrix
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              'Confusion Matrix',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: predicted labels
                Row(
                  children: [
                    const SizedBox(width: 120, child: Text('')),
                    ...labels.map((l) => Container(
                          width: 72,
                          padding: const EdgeInsets.all(6),
                          alignment: Alignment.center,
                          child: Text(l, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                // Rows
                ...List.generate(labels.length, (r) {
                  final trueLabel = labels[r];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        padding: const EdgeInsets.all(6),
                        child: Text(trueLabel, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                      ),
                      ...List.generate(labels.length, (c) {
                        final count = matrix[r][c];
                        final intensity = maxCount > 0 ? (count / maxCount) : 0.0;
                        final bg = Color.lerp(Colors.white, const Color(0xFF6366F1).withOpacity(0.9), intensity)!;
                        return Tooltip(
                          message: '${labels[r]} → ${labels[c]}: $count',
                          child: Container(
                            width: 72,
                            height: 48,
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.withOpacity(0.12)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: intensity > 0.5 ? Colors.white : Colors.grey[800],
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategories() {
    final stats = HistoryService.instance.getStats();
    final counts = stats['counts'] as Map<String, int>;
    
    // Sort by count and take top 5
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sorted.take(5).toList();

    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Categories',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Most frequently classified items',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          if (topCategories.isEmpty)
            Center(
              child: Text(
                'No classifications yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            )
          else
            ...topCategories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return _buildCategoryItem(
                {
                  'name': category.key,
                  'count': category.value,
                  'color': colors[index % colors.length],
                },
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    final name = category['name'] as String;
    final count = category['count'] as int;
    final color = category['color'] as Color;
    
    final stats = HistoryService.instance.getStats();
    final totalCount = stats['total'] as int;
    final percentage = totalCount > 0 ? (count / totalCount) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              Text(
                '$count (${percentage.toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: totalCount > 0 ? (count / totalCount) : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}