import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _chartLoading = false;
  String _activeRange = '7d';

  int _totalToday = 0;
  int _totalWeek = 0;
  int _totalMonth = 0;
  int _totalAllTime = 0;
  int _unreadMessages = 0;

  List<Map<String, dynamic>> _chartData = [];
  Map<String, int> _pageBreakdown = {};
  List<int> _hourlyData = List.filled(24, 0);

  final List<Map<String, String>> _ranges = [
    {'label': 'Last 7 days', 'value': '7d'},
    {'label': 'Last 30 days', 'value': '30d'},
    {'label': 'All time', 'value': 'all'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadStatCards(),
      _loadChartData(_activeRange),
    ]);
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime? _getRangeStart(String range) {
    if (range == 'all') return null;
    final d = DateTime.now();
    final startOfDay = DateTime(d.year, d.month, d.day);
    return startOfDay.subtract(Duration(days: range == '7d' ? 6 : 29));
  }

  Future<void> _loadStatCards() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);

    try {
      final futures = await Future.wait([
        SupabaseService.from('page_views')
            .select('id')
            .gte('visited_at', startOfDay.toIso8601String())
            .count(),
        SupabaseService.from('page_views')
            .select('id')
            .gte('visited_at', startOfWeek.toIso8601String())
            .count(),
        SupabaseService.from('page_views')
            .select('id')
            .gte('visited_at', startOfMonth.toIso8601String())
            .count(),
        SupabaseService.from('page_views')
            .select('id')
            .count(),
        SupabaseService.from('conversations')
            .select('id')
            .gt('unread_count_admin', 0)
            .count(),
      ]);

      _totalToday = futures[0].count;
      _totalWeek = futures[1].count;
      _totalMonth = futures[2].count;
      _totalAllTime = futures[3].count;
      _unreadMessages = futures[4].count;

      final todayViews = await SupabaseService.from('page_views')
          .select('visited_at')
          .gte('visited_at', startOfDay.toIso8601String());

      _hourlyData = List.filled(24, 0);
      for (var view in (todayViews as List)) {
        final dt = DateTime.parse(view['visited_at']);
        _hourlyData[dt.hour]++;
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadChartData(String range) async {
    if (mounted) {
      setState(() {
        _chartLoading = true;
      });
    }

    final rangeStart = _getRangeStart(range);
    
    try {
      var query = SupabaseService.from('page_views')
          .select('visited_at, page');
          
      if (rangeStart != null) {
        query = query.gte('visited_at', rangeStart.toIso8601String());
      }

      final views = await query.order('visited_at', ascending: true);

      // Process views by day
      final grouped = <String, int>{};
      final pages = <String, int>{};
      
      for (var view in views) {
        final dt = DateTime.parse(view['visited_at']);
        if (rangeStart != null && dt.isBefore(rangeStart)) continue;
        
        final key = DateFormat('MMM d').format(dt);
        grouped[key] = (grouped[key] ?? 0) + 1;

        final page = view['page'] ?? '/';
        pages[page] = (pages[page] ?? 0) + 1;
      }

      _chartData = grouped.entries.map((e) => {'day': e.key, 'count': e.value}).toList();
      _pageBreakdown = pages;
      
    } catch (e) {
      debugPrint('Error loading chart data: $e');
    }

    if (mounted) {
      setState(() {
        _chartLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Portfolio analytics overview',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Stat Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final cards = [
                StatCard(
                  label: 'Today',
                  value: _totalToday.toString(),
                  color: AppColors.accentDark,
                  icon: '👁️',
                ),
                StatCard(
                  label: 'This Week',
                  value: _totalWeek.toString(),
                  color: AppColors.purple,
                  icon: '📅',
                ),
                StatCard(
                  label: 'This Month',
                  value: _totalMonth.toString(),
                  color: AppColors.pink,
                  icon: '📆',
                ),
                StatCard(
                  label: 'All Time',
                  value: _totalAllTime.toString(),
                  color: AppColors.warning,
                  icon: '🌍',
                ),
                StatCard(
                  label: 'Unread Messages',
                  value: _unreadMessages.toString(),
                  color: AppColors.success,
                  icon: '✉️',
                ),
              ];

              if (isMobile) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: cards.map((c) => Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 16),
                      child: c,
                    )).toList(),
                  ),
                );
              }

              int crossAxisCount = constraints.maxWidth > 1100 ? 5 : constraints.maxWidth > 800 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 180 / 120, // Approx web ratio
                children: cards,
              );
            },
          ),
          const SizedBox(height: 24),

          // Range Filter
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Showing:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              ..._ranges.map((r) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        setState(() => _activeRange = r['value']!);
                        _loadChartData(r['value']!);
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _activeRange == r['value'] ? AppColors.accentDark : AppColors.surfaceAlt,
                          border: Border.all(
                            color: _activeRange == r['value'] ? AppColors.accentDark : AppColors.border,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          r['label']!,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: _activeRange == r['value'] ? Colors.white : AppColors.textBody,
                              ),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 24),

          // Charts Row 1
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 768;
              List<Widget> children = [
                // Line Chart
                Expanded(
                  flex: isMobile ? 0 : 2,
                  child: Container(
                    height: 320,
                    margin: EdgeInsets.only(bottom: isMobile ? 16 : 0),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Visits — ${_ranges.firstWhere((r) => r['value'] == _activeRange)['label']}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accentDark.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'DAILY',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.accentDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _chartLoading
                              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                              : LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 1,
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            if (value.toInt() >= 0 && value.toInt() < _chartData.length) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 8.0),
                                                child: Text(
                                                  _chartData[value.toInt()]['day'],
                                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                                ),
                                              );
                                            }
                                            return const Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          reservedSize: 42,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    minX: 0,
                                    maxX: _chartData.isEmpty ? 0 : (_chartData.length - 1).toDouble(),
                                    minY: 0,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _chartData.asMap().entries.map((e) {
                                          return FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble());
                                        }).toList(),
                                        isCurved: true,
                                        color: AppColors.accentDark,
                                        barWidth: 2,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter: (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: AppColors.accentDark,
                                              strokeWidth: 0,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: AppColors.accentDark.withValues(alpha: 0.07),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isMobile) const SizedBox(width: 20),
                
                // Doughnut Chart
                Expanded(
                  flex: isMobile ? 0 : 1,
                  child: Container(
                    height: 320,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Pages Visited',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'BREAKDOWN',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.purple),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: _chartLoading
                              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 60,
                                    sections: () {
                                      final colors = [
                                        AppColors.accentDark,
                                        AppColors.purple,
                                        AppColors.pink,
                                        AppColors.warning,
                                        AppColors.success,
                                        AppColors.blue,
                                      ];
                                      final entries = _pageBreakdown.entries.toList()
                                        ..sort((a, b) => b.value.compareTo(a.value));
                                      final topEntries = entries.take(6).toList();
                                      
                                      return topEntries.asMap().entries.map((e) {
                                        return PieChartSectionData(
                                          color: colors[e.key % colors.length].withValues(alpha: 0.75),
                                          value: e.value.value.toDouble(),
                                          title: '',
                                          radius: 30,
                                          borderSide: const BorderSide(color: Colors.white, width: 3),
                                        );
                                      }).toList();
                                    }(),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ];

              return isMobile
                  ? Column(children: children)
                  : Row(children: children);
            },
          ),
          const SizedBox(height: 20),

          // Charts Row 2 (Bar Chart)
          Container(
            height: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Hourly Traffic — Today',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '24H',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.pink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value % 2 == 0) { // Show every 2 hours to prevent crowding
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '${value.toInt()}:00',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _hourlyData.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: e.value.toDouble(),
                              color: e.key % 2 == 0 
                                ? AppColors.accentDark.withValues(alpha: 0.65)
                                : AppColors.purple.withValues(alpha: 0.65),
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
