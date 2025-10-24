class BiometricSample {
  BiometricSample({
    required this.date,
    required this.hrv,
    required this.rhr,
    required this.steps,
    required this.sleepScore,
  });

  final DateTime date;
  final double? hrv;
  final int? rhr;
  final int? steps;
  final int? sleepScore;

  static BiometricSample? fromJson(Map<String, dynamic> json) {
    final dateString = json['date'] as String?;
    if (dateString == null) {
      return null;
    }

    DateTime? date;
    try {
      date = DateTime.parse(dateString);
    } catch (_) {
      return null;
    }

    double? parseDouble(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is int) {
        return value;
      }
      if (value is double) {
        return value.round();
      }
      return int.tryParse(value.toString());
    }

    return BiometricSample(
      date: date,
      hrv: parseDouble(json['hrv']),
      rhr: parseInt(json['rhr']),
      steps: parseInt(json['steps']),
      sleepScore: parseInt(json['sleepScore']),
    );
  }

  BiometricSample copyWith({
    DateTime? date,
    double? hrv,
    int? rhr,
    int? steps,
    int? sleepScore,
  }) {
    return BiometricSample(
      date: date ?? this.date,
      hrv: hrv ?? this.hrv,
      rhr: rhr ?? this.rhr,
      steps: steps ?? this.steps,
      sleepScore: sleepScore ?? this.sleepScore,
    );
  }

  @override
  int get hashCode => Object.hash(date.millisecondsSinceEpoch, hrv, rhr, steps, sleepScore);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BiometricSample &&
            other.date == date &&
            other.hrv == hrv &&
            other.rhr == rhr &&
            other.steps == steps &&
            other.sleepScore == sleepScore;
  }

  static List<BiometricSample> sortByDate(Iterable<BiometricSample> samples) {
    final sorted = samples.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }
}
