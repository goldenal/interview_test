import 'dart:math';

class TimeSeriesDecimator {
  const TimeSeriesDecimator();

  /// Applies Largest-Triangle-Three-Buckets decimation.
  ///
  /// The implementation preserves the first and last sample and ensures the
  /// output length does not exceed [threshold]. When [threshold] is greater
  /// than or equal to [data.length], the original list is returned.
  List<T> lttb<T>({
    required List<T> data,
    required int threshold,
    required DateTime Function(T point) getX,
    required double Function(T point) getY,
  }) {
    if (threshold <= 0 || data.length <= threshold) {
      return List<T>.from(data);
    }
    if (data.length < 3) {
      return List<T>.from(data);
    }

    final sampled = <T>[];
    sampled.add(data.first);

    final bucketSize = (data.length - 2) / (threshold - 2);
    var a = 0;
    for (var i = 0; i < threshold - 2; i++) {
      final rangeStart = (1 + (i * bucketSize)).floor();
      final rangeEnd = min(data.length - 1, (1 + ((i + 1) * bucketSize)).floor());

      var avgX = 0.0;
      var avgY = 0.0;
      final rangeLength = rangeEnd - rangeStart;
      if (rangeLength > 0) {
        for (var idx = rangeStart; idx < rangeEnd; idx++) {
          avgX += getX(data[idx]).millisecondsSinceEpoch.toDouble();
          avgY += getY(data[idx]);
        }
        avgX /= rangeLength;
        avgY /= rangeLength;
      } else {
        avgX = getX(data[rangeStart]).millisecondsSinceEpoch.toDouble();
        avgY = getY(data[rangeStart]);
      }

      var areaMax = -1.0;
      var nextA = rangeStart;

      final rangeAStart = rangeStart;
      final rangeAEnd = min(data.length - 1, rangeEnd + 1);
      for (var idx = rangeAStart; idx < rangeAEnd; idx++) {
        final pointA = data[a];
        final pointB = data[idx];
        final ax = getX(pointA).millisecondsSinceEpoch.toDouble();
        final ay = getY(pointA);
        final bx = getX(pointB).millisecondsSinceEpoch.toDouble();
        final by = getY(pointB);

        final area = (ax - avgX) * (by - ay) - (ax - bx) * (avgY - ay);
        final absArea = area.abs();
        if (absArea > areaMax) {
          areaMax = absArea;
          nextA = idx;
        }
      }

      sampled.add(data[nextA]);
      a = nextA;
    }

    sampled.add(data.last);
    return sampled;
  }
}
