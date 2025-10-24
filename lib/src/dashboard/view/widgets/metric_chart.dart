import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../data/models/journal_entry.dart';
import '../biometrics_dashboard_controller.dart';

/// A chart point representing a single metric value at a specific time
class ChartPoint {
  const ChartPoint(this.time, this.y);

  final DateTime time;
  final double? y;
}

/// A range point representing min/max bounds at a specific time
class RangePoint {
  const RangePoint(this.time, this.low, this.high);

  final DateTime time;
  final double? low;
  final double? high;
}

/// Interactive metric chart with pan/zoom capabilities and journal annotations
class MetricChart extends StatefulWidget {
  const MetricChart({
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
    required this.isMobile,
    required this.isTablet,
  });

  final String title;
  final Color color;
  final List<ChartPoint> points;
  final List<RangePoint>? rangePoints;
  final double minY;
  final double maxY;
  final ZoomPanBehavior zoomPanBehavior;
  final DateTime? focusDate;
  final List<PlotBand> plotBands;
  final BiometricsDashboardController controller;
  final ValueChanged<JournalEntry>? onAnnotationTap;
  final List<JournalEntry> journals;
  final String Function(double value) axisLabelFormatter;
  final bool isMobile;
  final bool isTablet;

  @override
  State<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<MetricChart> {
  late TrackballBehavior _trackballBehavior;
  late TooltipBehavior _tooltipBehavior;

  @override
  void initState() {
    super.initState();
    _initTrackball();
    _tooltipBehavior = TooltipBehavior(enable: false);
  }

  @override
  void didUpdateWidget(covariant MetricChart oldWidget) {
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

    // Responsive text sizing for axes
    final axisLabelStyle = TextStyle(
      fontSize: widget.isMobile ? 10 : (widget.isTablet ? 11 : 12),
      color: theme.colorScheme.onSurface,
    );

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
      labelStyle: axisLabelStyle,
      // Enhanced zoom settings for better data exploration
      enableAutoIntervalOnZooming: true,
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
      labelStyle: axisLabelStyle,
      axisLabelFormatter: (args) {
        return ChartAxisLabel(
          widget.axisLabelFormatter(args.value.toDouble()),
          args.textStyle?.copyWith(
            fontSize: widget.isMobile ? 10 : (widget.isTablet ? 11 : 12),
          ),
        );
      },
    );

    final series = <CartesianSeries<dynamic, DateTime>>[];
    if (widget.rangePoints != null && widget.rangePoints!.isNotEmpty) {
      series.add(
        SplineRangeAreaSeries<RangePoint, DateTime>(
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
      SplineSeries<ChartPoint, DateTime>(
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
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: widget.isMobile ? 14 : (widget.isTablet ? 15 : null),
          ),
        ),
        SizedBox(height: widget.isMobile ? 6 : 8),
        Expanded(
          child: SfCartesianChart(
            annotations: annotations,
            tooltipBehavior: _tooltipBehavior,
            trackballBehavior: _trackballBehavior,
            zoomPanBehavior: widget.zoomPanBehavior,
            primaryXAxis: xAxis,
            primaryYAxis: yAxis,
            margin: EdgeInsets.all(widget.isMobile ? 4 : 8),
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
