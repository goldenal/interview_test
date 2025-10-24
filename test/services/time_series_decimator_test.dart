import 'package:flutter_test/flutter_test.dart';

import 'package:interview_test/src/dashboard/data/models/biometric_sample.dart';
import 'package:interview_test/src/dashboard/services/time_series_decimator.dart';

void main() {
  group('TimeSeriesDecimator', () {
    test('preserves first, last, and extreme points while meeting threshold', () {
      final decimator = TimeSeriesDecimator();
      final start = DateTime(2025, 1, 1);
      final samples = <BiometricSample>[];
      for (var i = 0; i < 200; i++) {
        final date = start.add(Duration(days: i));
        final hrv = i == 80
            ? 15.0
            : i == 120
                ? 120.0
                : 50 + (i % 10).toDouble();
        samples.add(
          BiometricSample(
            date: date,
            hrv: hrv,
            rhr: 60 + (i % 4),
            steps: 6000 + (i * 10),
            sleepScore: 70,
          ),
        );
      }
      final minSample = samples[80];
      final maxSample = samples[120];

      final decimated = decimator.lttb(
        data: samples,
        threshold: 50,
        getX: (sample) => sample.date,
        getY: (sample) => sample.hrv ?? 0,
      );

      expect(decimated.length <= 50, isTrue);
      expect(decimated.first, samples.first);
      expect(decimated.last, samples.last);
      expect(decimated.contains(minSample), isTrue);
      expect(decimated.contains(maxSample), isTrue);
    });
  });
}
