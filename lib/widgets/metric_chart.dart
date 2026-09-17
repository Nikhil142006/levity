import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/history_provider.dart';

class MetricChart extends ConsumerWidget {
  final String metricType;
  final Color color;

  const MetricChart({
    super.key,
    required this.metricType,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(metricHistoryProvider(metricType));

    return historyState.when(
      data: (data) {
        if (data == null || data['history'] == null || (data['history'] as List).isEmpty) {
          return Center(
            child: Text(
              'No history available',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
            ),
          );
        }

        final historyList = data['history'] as List;
        // Data comes as sorted array from today minus 6 days, up to today (descending from loop in python, actually we did range(6, -1, -1) which is 6, 5, 4, 3, 2, 1, 0)
        // Let's map it to FlSpot. X will be index (0 to 6), Y will be value.
        
        List<FlSpot> spots = [];
        double minY = double.infinity;
        double maxY = double.negativeInfinity;

        for (int i = 0; i < historyList.length; i++) {
          final point = historyList[i];
          final val = (point['value'] as num).toDouble();
          if (val < minY) minY = val;
          if (val > maxY) maxY = val;
          spots.add(FlSpot(i.toDouble(), val));
        }

        // Add some padding to Y axis
        final yPadding = (maxY - minY) * 0.2;
        if (yPadding == 0) {
          minY -= 10;
          maxY += 10;
        } else {
          minY -= yPadding;
          maxY += yPadding;
        }

        return LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 4,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              },
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
                    final index = value.toInt();
                    if (index < 0 || index >= historyList.length) return const SizedBox();
                    
                    // Display day like 'Mon', 'Tue' or just simple labels
                    final dateStr = historyList[index]['date'] as String;
                    final dateObj = DateTime.tryParse(dateStr);
                    String label = dateStr; // fallback to raw string
                    if (dateObj != null) {
                      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                      label = days[dateObj.weekday - 1];
                    } else {
                      // Abbreviate 'Week 1' to 'W1' and 'Month 1' to 'M1' to fit
                      label = label.replaceAll('Week ', 'W').replaceAll('Month ', 'M');
                    }
                    
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (historyList.length - 1).toDouble(),
            minY: minY,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.15),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (LineBarSpot touchedSpot) => Theme.of(context).colorScheme.surface,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((LineBarSpot touchedSpot) {
                    final dateStr = historyList[touchedSpot.x.toInt()]['date'];
                    return LineTooltipItem(
                      '${touchedSpot.y.toStringAsFixed(1)}\n',
                      TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: dateStr,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading chart: $err')),
    );
  }
}
