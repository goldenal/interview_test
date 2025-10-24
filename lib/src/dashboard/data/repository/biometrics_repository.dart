import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/biometric_sample.dart';
import '../models/biometrics_payload.dart';
import '../models/journal_entry.dart';

class BiometricsRepository {
  BiometricsRepository({
    AssetBundle? bundle,
    Duration latencyMin = const Duration(milliseconds: 700),
    Duration latencyMax = const Duration(milliseconds: 1200),
    double failureProbability = 0.1,
    Random? random,
  })  : _bundle = bundle ?? rootBundle,
        _latencyMin = latencyMin,
        _latencyMax = latencyMax,
        _failureProbability = failureProbability.clamp(0, 1),
        _random = random ?? Random();

  final AssetBundle _bundle;
  final Duration _latencyMin;
  final Duration _latencyMax;
  final double _failureProbability;
  final Random _random;

  Future<BiometricsPayload> fetchBiometrics(
      {bool simulateLargeDataset = false, int count = 0}) async {
    await _injectLatency();
    _maybeThrowFailure(count);

    final samples = await _loadSamples();
    final journals = await _loadJournals();

    final List<BiometricSample> finalSamples;
    if (simulateLargeDataset && samples.isNotEmpty) {
      finalSamples = _expandDataset(samples, targetCount: 10800);
    } else {
      finalSamples = samples;
    }

    final sortedSamples = BiometricSample.sortByDate(finalSamples);
    final sortedJournals = _sortJournals(journals);

    return BiometricsPayload(
      samples: sortedSamples,
      journals: sortedJournals,
    );
  }

  Future<List<BiometricSample>> _loadSamples() async {
    final raw = await _bundle.loadString('assets/biometrics_90d.json');
    final data = jsonDecode(raw);
    if (data is! List) {
      return const [];
    }
    final samples = <BiometricSample>[];
    for (final entry in data) {
      if (entry is Map<String, dynamic>) {
        final sample = BiometricSample.fromJson(entry);
        if (sample != null) {
          samples.add(sample);
        }
      }
    }
    return samples;
  }

  Future<List<JournalEntry>> _loadJournals() async {
    final raw = await _bundle.loadString('assets/journals.json');
    final data = jsonDecode(raw);
    if (data is! List) {
      return const [];
    }
    final journals = <JournalEntry>[];
    for (final entry in data) {
      if (entry is Map<String, dynamic>) {
        final journal = JournalEntry.fromJson(entry);
        if (journal != null) {
          journals.add(journal);
        }
      }
    }
    return journals;
  }

  Future<void> _injectLatency() {
    final minMillis = _latencyMin.inMilliseconds;
    final maxMillis = max(minMillis, _latencyMax.inMilliseconds);
    final delta = maxMillis - minMillis;
    final jitter = delta == 0 ? 0 : _random.nextInt(delta + 1);
    final duration = Duration(milliseconds: minMillis + jitter);
    return Future<void>.delayed(duration);
  }

  void _maybeThrowFailure(int count) {
    final roll = _random.nextDouble();
    if (count % 3 == 0) {
      throw BiometricsLoadException('Failed to load biometrics data');
    }
  }

  List<JournalEntry> _sortJournals(List<JournalEntry> journals) {
    final sorted = journals.toList()..sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  List<BiometricSample> _expandDataset(
    List<BiometricSample> base, {
    required int targetCount,
  }) {
    if (base.isEmpty) {
      return base;
    }

    final expanded = <BiometricSample>[];
    var lastDate = base.last.date;
    while (expanded.length < targetCount) {
      for (final sample in base) {
        if (expanded.length >= targetCount) {
          break;
        }
        lastDate = lastDate.add(const Duration(days: 1));
        final jitterHrv = _jitterDouble(sample.hrv, 2.5);
        final jitterRhr = _jitterInt(sample.rhr, 2);
        final jitterSteps = _jitterInt(sample.steps, 1800, lowerBound: 0);
        final jitterSleep =
            _jitterInt(sample.sleepScore, 6, lowerBound: 0, upperBound: 100);
        expanded.add(BiometricSample(
          date: lastDate,
          hrv: jitterHrv,
          rhr: jitterRhr,
          steps: jitterSteps,
          sleepScore: jitterSleep,
        ));
      }
    }

    return [
      ...base,
      ...expanded,
    ];
  }

  double? _jitterDouble(double? value, double deviation) {
    if (value == null) {
      return null;
    }
    final noise = _random.nextDouble() * deviation * 2 - deviation;
    return double.parse((value + noise).toStringAsFixed(1));
  }

  int? _jitterInt(
    int? value,
    int deviation, {
    int? lowerBound,
    int? upperBound,
  }) {
    if (value == null) {
      return null;
    }
    final noise = _random.nextInt(deviation * 2 + 1) - deviation;
    var result = value + noise;
    if (lowerBound != null) {
      result = max(result, lowerBound);
    }
    if (upperBound != null) {
      result = min(result, upperBound);
    }
    return result;
  }
}

class BiometricsLoadException implements Exception {
  BiometricsLoadException(this.message);

  final String message;

  @override
  String toString() => 'BiometricsLoadException: $message';
}
