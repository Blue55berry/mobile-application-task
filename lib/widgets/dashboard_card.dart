import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool showChart;
  final List<FlSpot>? chartData; // Real data for chart

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.showChart = false,
    this.chartData, // Optional chart data
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
            ],
          ),
          if (showChart) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData ?? _generateDefaultSpots(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.5), color],
                      ),
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: color,
                            strokeWidth: 1.5,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.0),
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
        ],
      ),
    );
  }

  List<FlSpot> _generateDefaultSpots() {
    return List.generate(
      7,
      (index) => FlSpot(index.toDouble(), index % 2 == 0 ? 2 : 3),
    );
  }
}
