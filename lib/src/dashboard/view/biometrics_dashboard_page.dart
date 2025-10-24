import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../data/models/biometric_sample.dart';
import '../data/models/journal_entry.dart';
import '../domain/range_option.dart';
import '../services/rolling_statistics.dart';
import 'biometrics_dashboard_controller.dart';

class BiometricsDashboardPage extends StatelessWidget {
  const BiometricsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<BiometricsDashboardController>(
          builder: (context, controller, _) {
            switch (controller.status) {
              case DashboardStatus.loading:
              case DashboardStatus.idle:
                return const _LoadingState();
              case DashboardStatus.error:
                return _ErrorState(
                  message: controller.errorMessage ?? 'Unexpected error',
                  onRetry: controller.retry,
                );
              case DashboardStatus.empty:
                return const _EmptyState();
              case DashboardStatus.ready:
                return _DashboardBody(controller: controller);
            }
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.controller});

  final BiometricsDashboardController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final scrollable = constraints.maxHeight < 720;
        final EdgeInsets padding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 24,
          vertical: compact ? 12 : 24,
        );
        final content = _DashboardContent(
          controller: controller,
          compact: compact,
          scrollable: scrollable,
        );
        if (scrollable) {
          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }
        return Padding(
          padding: padding,
          child: content,
        );
      },
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.controller,
    required this.compact,
    required this.scrollable,
  });

  final BiometricsDashboardController controller;
  final bool compact;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusSample = controller.sampleNearestTo(controller.focusDate);
    final stats = controller.statsNearestTo(controller.focusDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          controller: controller,
          compact: compact,
        ),
        const SizedBox(height: 12),
        _RangeSelector(
          controller: controller,
          compact: compact,
        ),
        const SizedBox(height: 12),
        _FocusSummaryCard(
          sample: focusSample,
          stats: stats,
          compact: compact,
        ),
        const SizedBox(height: 16),
        if (scrollable)
          SizedBox(
            height: compact ? 600 : 680,
            child: _ChartsSection(controller: controller),
          )
        else
          Expanded(child: _ChartsSection(controller: controller)),
        const SizedBox(height: 12),
        if (controller.journals.isNotEmpty)
          _JournalList(journals: controller.journals),
        if (controller.journals.isNotEmpty) const SizedBox(height: 12),
        Text(
          'Pan or pinch to explore. Hover or tap charts to sync metrics.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.controller, required this.compact});

  final BiometricsDashboardController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Biometrics Overview',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'HRV, resting HR, and activity trends with journal context.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _LargeDatasetToggle(
          value: controller.simulateLargeDataset,
          onChanged: (value) => controller.toggleLargeDataset(value),
          compact: compact,
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.controller,
    required this.compact,
  });

  final BiometricsDashboardController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Range',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SegmentedButton<RangeOption>(
          segments: RangeOption.values
              .map(
                (option) => ButtonSegment<RangeOption>(
                  value: option,
                  label: Text(option.label),
                ),
              )
              .toList(),
          selected: <RangeOption>{controller.range},
          showSelectedIcon: false,
          style: ButtonStyle(
            padding: WidgetStateProperty.resolveWith(
              (states) => EdgeInsets.symmetric(
                horizontal: compact ? 12 : 20,
                vertical: 10,
              ),
            ),
          ),
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              controller.changeRange(selection.first);
            }
          },
        ),
      ],
    );
  }
}

class _LargeDatasetToggle extends StatelessWidget {
  const _LargeDatasetToggle({
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Large dataset',
          style: theme.textTheme.labelLarge,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
            if (!compact) const SizedBox(width: 8),
            if (!compact)
              Text(
                'Simulate 10k+ points',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }
}

class _FocusSummaryCard extends StatelessWidget {
  const _FocusSummaryCard({
    required this.sample,
    required this.stats,
    required this.compact,
  });

  final BiometricSample? sample;
  final RollingStatsPoint? stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE, MMM d');
    final numberFormat = NumberFormat('###.0');

    final dateLabel =
        sample?.date != null ? dateFormat.format(sample!.date) : 'No data';
    final hrvValue =
        sample?.hrv != null ? '${numberFormat.format(sample!.hrv)} ms' : '—';
    final rhrValue = sample?.rhr != null ? '${sample!.rhr} bpm' : '—';
    final stepsValue = sample?.steps != null
        ? '${NumberFormat.compact().format(sample!.steps)} steps'
        : '—';
    final sleepValue =
        sample?.sleepScore != null ? '${sample!.sleepScore}' : '—';
    final statsLabel = (stats?.mean != null &&
            stats?.lower != null &&
            stats?.upper != null)
        ? '${numberFormat.format(stats!.mean)} ± ${numberFormat.format((stats!.upper! - stats!.lower!) / 2)}'
        : '—';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _MetricChip(label: 'HRV', value: hrvValue),
                _MetricChip(label: 'Resting HR', value: rhrValue),
                _MetricChip(label: 'Steps', value: stepsValue),
                _MetricChip(label: 'Sleep score', value: sleepValue),
                _MetricChip(label: '7d mean ±1σ', value: statsLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ChartsSection extends StatefulWidget {
  const _ChartsSection({required this.controller});

  final BiometricsDashboardController controller;

  @override
  State<_ChartsSection> createState() => _ChartsSectionState();
}

class _ChartsSectionState extends State<_ChartsSection> {
  late ZoomPanBehavior _zoomBehaviorHrv;
  late ZoomPanBehavior _zoomBehaviorRhr;
  late ZoomPanBehavior _zoomBehaviorSteps;

  @override
  void initState() {
    super.initState();
    _zoomBehaviorHrv = ZoomPanBehavior(
        enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x);
    _zoomBehaviorRhr = ZoomPanBehavior(
        enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x);
    _zoomBehaviorSteps = ZoomPanBehavior(
        enablePinching: true, enablePanning: true, zoomMode: ZoomMode.x);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final samples = controller.chartSamples;
    final stats = controller.chartStats;
    final focusDate = controller.focusDate;

    final hrvPoints = samples
        .map((sample) => _ChartPoint(sample.date, sample.hrv))
        .where((point) => point.y != null)
        .toList();
    final hrvBands = stats
        .map(
          (stat) => _RangePoint(
            stat.date,
            stat.lower,
            stat.upper,
          ),
        )
        .where((point) => point.low != null && point.high != null)
        .toList();
    final rhrPoints = samples
        .map((sample) => _ChartPoint(sample.date, sample.rhr?.toDouble()))
        .where((point) => point.y != null)
        .toList();
    final stepsPoints = samples
        .map((sample) => _ChartPoint(sample.date, sample.steps?.toDouble()))
        .where((point) => point.y != null)
        .toList();

    final hrvMax = _maxValue(hrvBands
        .map((band) => band.high ?? 0)
        .followedBy(hrvPoints.map((p) => p.y ?? 0)));
    final hrvMin = _minValue(hrvBands
        .map((band) => band.low ?? 0)
        .followedBy(hrvPoints.map((p) => p.y ?? 0)));
    final rhrMax = _maxValue(rhrPoints.map((p) => p.y ?? 0));
    final rhrMin = _minValue(rhrPoints.map((p) => p.y ?? 0));
    final stepsMax = _maxValue(stepsPoints.map((p) => p.y ?? 0));
    final stepsMin = _minValue(stepsPoints.map((p) => p.y ?? 0));

    final plotBands = _buildPlotBands(
      focusDate: focusDate,
      journals: controller.journals,
      color: Theme.of(context).colorScheme.secondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _MetricChart(
            title: 'Heart Rate Variability (ms)',
            color: Colors.teal,
            points: hrvPoints,
            rangePoints: hrvBands,
            minY: hrvMin,
            maxY: hrvMax,
            zoomPanBehavior: _zoomBehaviorHrv,
            focusDate: focusDate,
            plotBands: plotBands,
            controller: controller,
            onAnnotationTap: (entry) => _showJournal(context, entry),
            journals: controller.journals,
            axisLabelFormatter: (value) => value.toStringAsFixed(0),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _MetricChart(
            title: 'Resting Heart Rate (bpm)',
            color: Colors.deepOrange,
            points: rhrPoints,
            minY: rhrMin,
            maxY: rhrMax,
            zoomPanBehavior: _zoomBehaviorRhr,
            focusDate: focusDate,
            plotBands: plotBands,
            controller: controller,
            axisLabelFormatter: (value) => value.toStringAsFixed(0),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _MetricChart(
            title: 'Steps',
            color: Colors.blueAccent,
            points: stepsPoints,
            minY: stepsMin,
            maxY: stepsMax,
            zoomPanBehavior: _zoomBehaviorSteps,
            focusDate: focusDate,
            plotBands: plotBands,
            controller: controller,
            axisLabelFormatter: (value) => NumberFormat.compact().format(value),
          ),
        ),
      ],
    );
  }

  void _showJournal(BuildContext context, JournalEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(DateFormat.yMMMd().format(entry.date)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mood: ${entry.mood}/5'),
              const SizedBox(height: 8),
              Text(entry.note),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _MetricChart extends StatefulWidget {
  const _MetricChart({
    super.key,
    required this.title,
    required this.color,
    required this.points,
    this.rangePoints,
    required this.minY,
    required this.maxY,
    required this.zoomPanBehavior,
    required this.focusDate,
    required this.plotBands,
    required this.controller,
    this.onAnnotationTap,
    this.journals = const [],
    required this.axisLabelFormatter,
  });

  final String title;
  final Color color;
  final List<_ChartPoint> points;
  final List<_RangePoint>? rangePoints;
  final double minY;
  final double maxY;
  final ZoomPanBehavior zoomPanBehavior;
  final DateTime? focusDate;
  final List<PlotBand> plotBands;
  final BiometricsDashboardController controller;
  final ValueChanged<JournalEntry>? onAnnotationTap;
  final List<JournalEntry> journals;
  final String Function(double value) axisLabelFormatter;

  @override
  State<_MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<_MetricChart> {
  late TrackballBehavior _trackballBehavior;
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _initTrackball();
    _tooltipBehavior = TooltipBehavior(enable: false);
  }

  @override
  void didUpdateWidget(covariant _MetricChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _initTrackball();
    }
  }

  void _initTrackball() {
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      tooltipSettings: const InteractiveTooltip(enable: false),
      lineType: TrackballLineType.vertical,
      lineColor: widget.color.withValues(alpha: 0.7),
      lineWidth: 1.5,
      shouldAlwaysShow: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisLineColor = theme.colorScheme.outlineVariant;
    final xAxis = DateTimeAxis(
      plotBands: widget.plotBands,
      edgeLabelPlacement: EdgeLabelPlacement.shift,
      dateFormat: DateFormat.MMMd(),
      intervalType: DateTimeIntervalType.days,
      majorGridLines: const MajorGridLines(width: 0.2),
      majorTickLines: const MajorTickLines(width: 0),
      axisLine: AxisLine(color: axisLineColor, width: 0.5),
      rangeController: widget.controller.rangeController,
      minimum: widget.controller.dataStart,
      maximum: widget.controller.dataEnd,
    );

    final yAxis = NumericAxis(
      opposedPosition: true,
      majorGridLines: MajorGridLines(
        color: axisLineColor.withValues(alpha: 0.4),
        width: 0.4,
      ),
      axisLine: const AxisLine(width: 0),
      majorTickLines: const MajorTickLines(width: 0),
      labelFormat: '{value}',
      minimum: widget.minY == double.infinity ? null : widget.minY * 0.9,
      maximum: widget.maxY == double.negativeInfinity ? null : widget.maxY * 1.05,
      numberFormat: NumberFormat.compact(),
      axisLabelFormatter: (args) {
        return ChartAxisLabel(
          widget.axisLabelFormatter(args.value.toDouble()),
          args.textStyle,
        );
      },
    );

    final series = <CartesianSeries<dynamic, DateTime>>[];
    if (widget.rangePoints != null && widget.rangePoints!.isNotEmpty) {
      series.add(
        SplineRangeAreaSeries<_RangePoint, DateTime>(
          dataSource: widget.rangePoints!,
          color: widget.color.withValues(alpha: 0.12),
          borderColor: widget.color.withValues(alpha: 0.3),
          borderWidth: 1.5,
          xValueMapper: (point, _) => point.time,
          highValueMapper: (point, _) => point.high,
          lowValueMapper: (point, _) => point.low,
          emptyPointSettings: const EmptyPointSettings(mode: EmptyPointMode.drop),
        ),
      );
    }
    series.add(
      SplineSeries<_ChartPoint, DateTime>(
        dataSource: widget.points,
        color: widget.color,
        width: 2,
        xValueMapper: (point, _) => point.time,
        yValueMapper: (point, _) => point.y,
        emptyPointSettings: const EmptyPointSettings(mode: EmptyPointMode.drop),
      ),
    );

    final annotations = widget.journals
        .map(
          (entry) => CartesianChartAnnotation(
            coordinateUnit: CoordinateUnit.point,
            region: AnnotationRegion.chart,
            x: entry.date,
            y: widget.maxY.isFinite ? widget.maxY : 0,
            widget: GestureDetector(
              onTap: widget.onAnnotationTap != null
                  ? () => widget.onAnnotationTap!(entry)
                  : null,
              child: Tooltip(
                message:
                    '${DateFormat.MMMd().format(entry.date)} • Mood ${entry.mood}/5',
                child: Icon(
                  Icons.push_pin,
                  size: 16,
                  color: widget.color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SfCartesianChart(
            annotations: annotations,
            tooltipBehavior: _tooltipBehavior,
            trackballBehavior: _trackballBehavior,
            zoomPanBehavior: widget.zoomPanBehavior,
            primaryXAxis: xAxis,
            primaryYAxis: yAxis,
            onActualRangeChanged: (args) {
              if (args.orientation == AxisOrientation.horizontal) {
                final start = _toDateTime(args.visibleMin);
                final end = _toDateTime(args.visibleMax);
                widget.controller.updateVisibleRange(start, end);
              }
            },
            onTrackballPositionChanging: (args) {
              final raw = args.chartPointInfo.chartPoint?.xValue;
              if (raw is num) {
                final date = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
                widget.controller.setFocusDate(date);
              }
            },
            series: series,
          ),
        ),
      ],
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}

class _ChartPoint {
  const _ChartPoint(this.time, this.y);

  final DateTime time;
  final double? y;
}

class _RangePoint {
  const _RangePoint(this.time, this.low, this.high);

  final DateTime time;
  final double? low;
  final double? high;
}

double _maxValue(Iterable<double> values) {
  var maxValue = double.negativeInfinity;
  for (final value in values) {
    if (value.isFinite && value > maxValue) {
      maxValue = value;
    }
  }
  return maxValue;
}

double _minValue(Iterable<double> values) {
  var minValue = double.infinity;
  for (final value in values) {
    if (value.isFinite && value < minValue) {
      minValue = value;
    }
  }
  return minValue;
}

List<PlotBand> _buildPlotBands({
  required DateTime? focusDate,
  required List<JournalEntry> journals,
  required Color color,
}) {
  final bands = <PlotBand>[];
  if (focusDate != null) {
    bands.add(
      PlotBand(
        isVisible: true,
        start: focusDate.subtract(const Duration(hours: 6)),
        end: focusDate.add(const Duration(hours: 6)),
        color: color.withValues(alpha: 0.07),
        borderColor: color.withValues(alpha: 0.5),
        borderWidth: 1.2,
      ),
    );
  }

  for (final entry in journals) {
    bands.add(
      PlotBand(
        isVisible: true,
        start: entry.date.subtract(const Duration(hours: 8)),
        end: entry.date.add(const Duration(hours: 8)),
        color: color.withValues(alpha: 0.05),
        borderColor: color.withValues(alpha: 0.25),
        borderWidth: 1,
      ),
    );
  }
  return bands;
}

class _JournalList extends StatelessWidget {
  const _JournalList({required this.journals});

  final List<JournalEntry> journals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal Highlights',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final entry in journals)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dateFormat.format(entry.date)} • Mood ${entry.mood}/5',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.note,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final padding = EdgeInsets.symmetric(
          horizontal: compact ? 12 : 24,
          vertical: compact ? 16 : 32,
        );
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SkeletonBox(
                  height: 28,
                  width: 240,
                  color: theme.colorScheme.surfaceContainerHighest),
              const SizedBox(height: 16),
              _SkeletonBox(
                  height: 18,
                  width: 320,
                  color: theme.colorScheme.surfaceContainerHighest),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _SkeletonCard()),
                    const SizedBox(height: 16),
                    Expanded(child: _SkeletonCard()),
                    const SizedBox(height: 16),
                    Expanded(child: _SkeletonCard()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _SkeletonBox(height: 20, width: 160, color: color),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({
    required this.height,
    this.width,
    required this.color,
  });

  final double height;
  final double? width;
  final Color color;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.5),
                color.withValues(alpha: 0.3),
              ],
              stops: [
                (_controller.value * 0.5).clamp(0.0, 0.5),
                (_controller.value * 0.5 + 0.25).clamp(0.25, 0.75),
                (_controller.value * 0.5 + 0.5).clamp(0.5, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'We hit a snag',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No biometrics yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Data will appear as soon as we detect new samples.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
