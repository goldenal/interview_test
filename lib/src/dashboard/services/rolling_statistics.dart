import 'dart:collection';
import 'dart:math';

import '../data/models/biometric_sample.dart';

class RollingStatsPoint {
  RollingStatsPoint({
    required this.date,
    required this.mean,
    required this.lower,
    required this.upper,
  });

  final DateTime date;
  final double? mean;
  final double? lower;
  final double? upper;
}

class RollingStatisticsCalculator {
  RollingStatisticsCalculator({this.windowSize = 7}) : assert(windowSize > 1, 'windowSize must be >1');

  final int windowSize;

  List<RollingStatsPoint> calculate(Iterable<BiometricSample> samples) {
    final queue = ListQueue<double>();
    final points = <RollingStatsPoint>[];
    final sorted = BiometricSample.sortByDate(samples);

    for (final sample in sorted) {
      final value = sample.hrv;
      if (value != null) {
        queue.add(value);
        if (queue.length > windowSize) {
          queue.removeFirst();
        }
      }

      if (queue.isEmpty) {
        points.add(RollingStatsPoint(
          date: sample.date,
          mean: null,
          lower: null,
          upper: null,
        ));
        continue;
      }

      final currentValues = queue.toList();
      final mean = currentValues.reduce((a, b) => a + b) / currentValues.length;
      final variance = currentValues.fold<double>(0, (sum, val) => sum + pow(val - mean, 2)) / currentValues.length;
      final stdDev = sqrt(variance);
      points.add(
        RollingStatsPoint(
          date: sample.date,
          mean: double.parse(mean.toStringAsFixed(2)),
          lower: double.parse((mean - stdDev).toStringAsFixed(2)),
          upper: double.parse((mean + stdDev).toStringAsFixed(2)),
        ),
      );
    }
    return points;
  }
}
