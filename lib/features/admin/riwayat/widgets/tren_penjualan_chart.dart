import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/format.dart';
import '../../../../data/models/laporan_penjualan.dart';

class TrenPenjualanChart extends StatelessWidget {
  final List<LaporanHarianItem> dataHarian;

  const TrenPenjualanChart({
    super.key,
    required this.dataHarian,
  });

  @override
  Widget build(BuildContext context) {
    if (dataHarian.isEmpty) {
      return Card(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 36, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.show_chart, size: 40, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text(
                  'Belum ada data grafik penjualan pada periode ini',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort ascending by date
    final sortedData = List<LaporanHarianItem>.from(dataHarian)
      ..sort((a, b) => a.tanggal.compareTo(b.tanggal));

    // Calculate max Y
    double maxY = 0;
    for (final item in sortedData) {
      if (item.total.toDouble() > maxY) {
        maxY = item.total.toDouble();
      }
    }
    if (maxY == 0) maxY = 100000;
    final chartMaxY = maxY * 1.25;

    // Calculate Trend indicator
    final trendInfo = _calculateTrend(sortedData);

    return Card(
      color: AppColors.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tren Penjualan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sortedData.length} hari terdata',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (trendInfo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: trendInfo.isUp
                          ? AppColors.successBg
                          : (trendInfo.isNeutral
                              ? AppColors.cardBgSecondary
                              : AppColors.errorBg),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      trendInfo.text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: trendInfo.isUp
                            ? AppColors.success
                            : (trendInfo.isNeutral
                                ? AppColors.textMuted
                                : AppColors.error),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: max(0, (sortedData.length - 1).toDouble()),
                  minY: 0,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: chartMaxY / 4 > 0 ? chartMaxY / 4 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: chartMaxY / 3 > 0 ? chartMaxY / 3 : 1,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              _formatCompactY(value),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: _getBottomInterval(sortedData.length),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedData.length) {
                            return const SizedBox.shrink();
                          }
                          final date = sortedData[index].tanggal;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.burgundyDark,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= sortedData.length) {
                            return null;
                          }
                          final item = sortedData[index];
                          final dateStr = DateFormat('d MMM yyyy', 'id_ID')
                              .format(item.tanggal);
                          return LineTooltipItem(
                            '$dateStr\n${AppFormat.currency(item.total)}\n(${item.jumlahTransaksi} trx)',
                            const TextStyle(
                              color: AppColors.cream,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < sortedData.length; i++)
                          FlSpot(i.toDouble(), sortedData[i].total.toDouble()),
                      ],
                      isCurved: sortedData.length > 2,
                      curveSmoothness: 0.35,
                      color: AppColors.burgundy,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: sortedData.length <= 15,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3.5,
                          color: AppColors.cardBg,
                          strokeWidth: 2,
                          strokeColor: AppColors.burgundy,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.burgundy.withValues(alpha: 0.28),
                            AppColors.burgundy.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getBottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 31) return 5;
    return (count / 6).ceilToDouble();
  }

  String _formatCompactY(double value) {
    if (value >= 1000000) {
      final val = value / 1000000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}jt';
    }
    if (value >= 1000) {
      final val = value / 1000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 0)}rb';
    }
    return value.toInt().toString();
  }

  _TrendInfo? _calculateTrend(List<LaporanHarianItem> items) {
    if (items.length < 2) return null;

    final mid = items.length ~/ 2;
    final firstHalf = items.sublist(0, mid);
    final secondHalf = items.sublist(mid);

    if (firstHalf.isEmpty || secondHalf.isEmpty) return null;

    final avgFirst =
        firstHalf.map((e) => e.total).reduce((a, b) => a + b) / firstHalf.length;
    final avgSecond =
        secondHalf.map((e) => e.total).reduce((a, b) => a + b) / secondHalf.length;

    if (avgFirst == 0 && avgSecond == 0) {
      return _TrendInfo(text: 'Stabil', isUp: false, isNeutral: true);
    }
    if (avgFirst == 0) {
      return _TrendInfo(text: '+100%', isUp: true, isNeutral: false);
    }

    final diff = ((avgSecond - avgFirst) / avgFirst) * 100;
    if (diff.abs() < 1) {
      return _TrendInfo(text: 'Stabil', isUp: false, isNeutral: true);
    }

    final sign = diff > 0 ? '+' : '';
    return _TrendInfo(
      text: '$sign${diff.toStringAsFixed(0)}%',
      isUp: diff > 0,
      isNeutral: false,
    );
  }
}

class _TrendInfo {
  final String text;
  final bool isUp;
  final bool isNeutral;

  _TrendInfo({
    required this.text,
    required this.isUp,
    required this.isNeutral,
  });
}
