import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_core/core.dart';

import '../data/models/biometric_sample.dart';
import '../data/models/biometrics_payload.dart';
import '../data/models/journal_entry.dart';
import '../data/repository/biometrics_repository.dart';
import '../domain/range_option.dart';
import '../services/rolling_statistics.dart';
import '../services/time_series_decimator.dart';

enum DashboardStatus { idle, loading, ready, error, empty }

class BiometricsDashboardController extends ChangeNotifier {
  BiometricsDashboardController({
    required this.repository,
    TimeSeriesDecimator? decimator,
    RollingStatisticsCalculator? rollingCalculator,
    int maxChartPoints = 900,
  })  : _decimator = decimator ?? const TimeSeriesDecimator(),
        _rollingCalculator = rollingCalculator ?? RollingStatisticsCalculator(),
        _maxChartPoints = maxChartPoints;

  final BiometricsRepository repository;
  final TimeSeriesDecimator _decimator;
  final RollingStatisticsCalculator _rollingCalculator;
  final int _maxChartPoints;

  DashboardStatus _status = DashboardStatus.idle;
  DashboardStatus get status => _status;

  RangeOption _range = RangeOption.ninetyDays;
  RangeOption get range => _range;

  bool _simulateLargeDataset = false;
  bool get simulateLargeDataset => _simulateLargeDataset;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BiometricsPayload? _payload;
  BiometricsPayload? get payload => _payload;

  List<BiometricSample> _chartSamples = const [];
  List<BiometricSample> get chartSamples => _chartSamples;

  List<RollingStatsPoint> _chartStats = const [];
  List<RollingStatsPoint> get chartStats => _chartStats;

  RangeController? _rangeController;
  RangeController? get rangeController => _rangeController;

  DateTime? _dataStart;
  DateTime? _dataEnd;

  DateTime? get dataStart => _dataStart;
  DateTime? get dataEnd => _dataEnd;

  DateTime? _visibleStart;
  DateTime? _visibleEnd;
  bool _updatingRangeController = false;

  DateTime? get visibleStart => _visibleStart;
  DateTime? get visibleEnd => _visibleEnd;

  DateTime? _focusDate;
  DateTime? get focusDate => _focusDate;

  List<JournalEntry> get journals => _payload?.journals ?? const [];

  @override
  void dispose() {
    _rangeController?.removeListener(_onRangeControllerChanged);
    _rangeController?.dispose();
    super.dispose();
  }

  Future<void> load({bool refresh = false}) async {
    if (!refresh && _status == DashboardStatus.loading) {
      return;
    }
    _setStatus(DashboardStatus.loading);
    _errorMessage = null;
    notifyListeners();
    try {
      final payload = await repository.fetchBiometrics(
        simulateLargeDataset: _simulateLargeDataset,
      );
      _payload = payload;
      if (payload.samples.isEmpty) {
        _chartSamples = const [];
        _chartStats = const [];
        _focusDate = null;
        _visibleStart = null;
        _visibleEnd = null;
        _dataStart = null;
        _dataEnd = null;
        _resetRangeController();
        _setStatus(DashboardStatus.empty);
        notifyListeners();
        return;
      }
      _buildChartSeries();
      _setStatus(DashboardStatus.ready);
      notifyListeners();
    } catch (error) {
      _chartSamples = const [];
      _chartStats = const [];
      _focusDate = null;
      _visibleStart = null;
      _visibleEnd = null;
      _dataStart = null;
      _dataEnd = null;
      _resetRangeController();
      _errorMessage = '$error';
      _setStatus(DashboardStatus.error);
      notifyListeners();
    }
  }

  void changeRange(RangeOption range) {
    if (_range == range) {
      return;
    }
    _range = range;
    _updateVisibleWindow();
    _syncRangeController();
    notifyListeners();
  }

  Future<void> toggleLargeDataset(bool value) async {
    if (_simulateLargeDataset == value) {
      return;
    }
    _simulateLargeDataset = value;
    await load(refresh: true);
  }

  void setFocusDate(DateTime? date) {
    if (_focusDate == date) {
      return;
    }
    _focusDate = date;
    notifyListeners();
  }

  void retry() {
    load(refresh: true);
  }

  void _buildChartSeries() {
    final samples = _payload?.samples ?? const [];
    if (samples.isEmpty) {
      _chartSamples = const [];
      _chartStats = const [];
      _visibleStart = null;
      _visibleEnd = null;
      _focusDate = null;
      return;
    }

    List<BiometricSample> working = samples;
    if (samples.length > _maxChartPoints) {
      working = _decimator.lttb(
        data: samples,
        threshold: _maxChartPoints,
        getX: (sample) => sample.date,
        getY: _sampleToValue,
      );
    }
    _chartSamples = working;
    _dataStart = working.first.date;
    _dataEnd = working.last.date;

    final stats = _rollingCalculator.calculate(samples);
    _chartStats = _alignStats(stats, working);

    _visibleEnd = working.last.date;
    _updateVisibleWindow();
    _focusDate ??= _visibleEnd;
    _syncRangeController();
  }

  List<RollingStatsPoint> _alignStats(
    List<RollingStatsPoint> stats,
    List<BiometricSample> samples,
  ) {
    if (stats.isEmpty) {
      return List<RollingStatsPoint>.generate(
        samples.length,
        (index) => RollingStatsPoint(
          date: samples[index].date,
          mean: null,
          lower: null,
          upper: null,
        ),
      );
    }

    final statsMap = <DateTime, RollingStatsPoint>{};
    for (final stat in stats) {
      statsMap[DateTime(stat.date.year, stat.date.month, stat.date.day)] = stat;
    }

    RollingStatsPoint? lastKnown;
    final aligned = <RollingStatsPoint>[];
    for (final sample in samples) {
      final key = DateTime(sample.date.year, sample.date.month, sample.date.day);
      final stat = statsMap[key] ?? lastKnown;
      if (stat != null) {
        aligned.add(
          RollingStatsPoint(
            date: sample.date,
            mean: stat.mean,
            lower: stat.lower,
            upper: stat.upper,
          ),
        );
        lastKnown = stat;
      } else {
        aligned.add(
          RollingStatsPoint(
            date: sample.date,
            mean: null,
            lower: null,
            upper: null,
          ),
        );
      }
    }
    return aligned;
  }

  void _updateVisibleWindow() {
    if (_chartSamples.isEmpty) {
      _visibleStart = null;
      _visibleEnd = null;
      return;
    }
    final end = _chartSamples.last.date;
    final startCandidate = end.subtract(Duration(days: _range.days - 1));
    final firstDate = _chartSamples.first.date;
    _visibleStart = startCandidate.isBefore(firstDate) ? firstDate : startCandidate;
    _visibleEnd = end;
  }

  double _sampleToValue(BiometricSample sample) {
    if (sample.hrv != null) {
      return sample.hrv!;
    }
    if (sample.steps != null) {
      return sample.steps!.toDouble();
    }
    if (sample.rhr != null) {
      return sample.rhr!.toDouble();
    }
    return 0;
  }

  void _setStatus(DashboardStatus status) {
    _status = status;
  }

  void _syncRangeController() {
    final start = _visibleStart;
    final end = _visibleEnd;
    if (start == null || end == null) {
      return;
    }

    if (_rangeController == null) {
      _rangeController = RangeController(start: start, end: end)
        ..addListener(_onRangeControllerChanged);
      return;
    }

    final currentStart = _rangeController!.start;
    final currentEnd = _rangeController!.end;
    if (currentStart is DateTime &&
        currentEnd is DateTime &&
        currentStart.millisecondsSinceEpoch == start.millisecondsSinceEpoch &&
        currentEnd.millisecondsSinceEpoch == end.millisecondsSinceEpoch) {
      return;
    }

    _updatingRangeController = true;
    _rangeController!.removeListener(_onRangeControllerChanged);
    _rangeController!
      ..start = start
      ..end = end;
    _rangeController!.addListener(_onRangeControllerChanged);
    _updatingRangeController = false;
  }

  void _resetRangeController() {
    _rangeController?.removeListener(_onRangeControllerChanged);
    _rangeController?.dispose();
    _rangeController = null;
  }

  void _onRangeControllerChanged() {
    if (_updatingRangeController) {
      return;
    }
    final controller = _rangeController;
    if (controller == null) {
      return;
    }
    final start = controller.start;
    final end = controller.end;
    if (start is! DateTime || end is! DateTime) {
      return;
    }
    final sameStart =
        _visibleStart?.millisecondsSinceEpoch == start.millisecondsSinceEpoch;
    final sameEnd =
        _visibleEnd?.millisecondsSinceEpoch == end.millisecondsSinceEpoch;
    if (sameStart && sameEnd) {
      return;
    }
    _visibleStart = start;
    _visibleEnd = end;
    notifyListeners();
  }

  void updateVisibleRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return;
    }
    final sameStart =
        _visibleStart?.millisecondsSinceEpoch == start.millisecondsSinceEpoch;
    final sameEnd =
        _visibleEnd?.millisecondsSinceEpoch == end.millisecondsSinceEpoch;
    if (sameStart && sameEnd) {
      return;
    }
    _visibleStart = start;
    _visibleEnd = end;
    _syncRangeController();
    notifyListeners();
  }

  BiometricSample? sampleNearestTo(DateTime? date) {
    if (date == null || _chartSamples.isEmpty) {
      return null;
    }
    BiometricSample? nearest;
    var minDiff = Duration(days: 10000);
    for (final sample in _chartSamples) {
      final diff = sample.date.difference(date).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = sample;
      }
    }
    return nearest;
  }

  RollingStatsPoint? statsNearestTo(DateTime? date) {
    if (date == null || _chartStats.isEmpty) {
      return null;
    }
    RollingStatsPoint? nearest;
    var minDiff = Duration(days: 10000);
    for (final stat in _chartStats) {
      final diff = stat.date.difference(date).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = stat;
      }
    }
    return nearest;
  }
}
