import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart' as sf;

import '../../data/models/journal_entry.dart';
import '../biometrics_dashboard_controller.dart';
import 'metric_chart.dart';

/// Utility functions for calculating min/max values
double maxValue(Iterable<double> values) {
  var maxVal = double.negativeInfinity;
  for (final value in values) {
    if (value.isFinite && value > maxVal) {
      maxVal = value;
    }
  }
  return maxVal;
}

double minValue(Iterable<double> values) {
  var minVal = double.infinity;
  for (final value in values) {
    if (value.isFinite && value < minVal) {
      minVal = value;
    }
  }
  return minVal;
}

/// Builds plot bands for focus date and journal entries
List<sf.PlotBand> buildPlotBands({
  required DateTime? focusDate,
  required List<JournalEntry> journals,
  required Color color,
}) {
  final bands = <sf.PlotBand>[];
  if (focusDate != null) {
    bands.add(
      sf.PlotBand(
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
      sf.PlotBand(
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

/// Charts section containing HRV, RHR, and Steps charts with synchronized pan/zoom
class ChartsSection extends StatefulWidget {
  const ChartsSection({
    super.key,
    required this.controller,
    required this.isMobile,
    required this.isTablet,
  });

  final BiometricsDashboardController controller;
  final bool isMobile;
  final bool isTablet;

  @override
  State<ChartsSection> createState() => _ChartsSectionState();
}

class _ChartsSectionState extends State<ChartsSection> {
  late sf.ZoomPanBehavior _zoomBehaviorHrv;
  late sf.ZoomPanBehavior _zoomBehaviorRhr;
  late sf.ZoomPanBehavior _zoomBehaviorSteps;

  @override
  void initState() {
    super.initState();
    // Enhanced zoom/pan configuration for better data exploration
    _zoomBehaviorHrv = sf.ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enableSelectionZooming: true,
      zoomMode: sf.ZoomMode.x,
      maximumZoomLevel: 0.1, // Allow zooming in to 10% of original view
    );
    _zoomBehaviorRhr = sf.ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enableSelectionZooming: true,
      zoomMode: sf.ZoomMode.x,
      maximumZoomLevel: 0.1,
    );
    _zoomBehaviorSteps = sf.ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      enableMouseWheelZooming: true,
      enableSelectionZooming: true,
      zoomMode: sf.ZoomMode.x,
      maximumZoomLevel: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final samples = controller.chartSamples;
    final stats = controller.chartStats;
    final focusDate = controller.focusDate;

    final hrvPoints = samples
        .map((sample) => ChartPoint(sample.date, sample.hrv))
        .where((point) => point.y != null)
        .toList();
    final hrvBands = stats
        .map(
          (stat) => RangePoint(
            stat.date,
            stat.lower,
            stat.upper,
          ),
        )
        .where((point) => point.low != null && point.high != null)
        .toList();
    final rhrPoints = samples
        .map((sample) => ChartPoint(sample.date, sample.rhr?.toDouble()))
        .where((point) => point.y != null)
        .toList();
    final stepsPoints = samples
        .map((sample) => ChartPoint(sample.date, sample.steps?.toDouble()))
        .where((point) => point.y != null)
        .toList();

    final hrvMax = maxValue(hrvBands
        .map((band) => band.high ?? 0.0)
        .followedBy(hrvPoints.map((p) => p.y ?? 0.0)));
    final hrvMin = minValue(hrvBands
        .map((band) => band.low ?? 0.0)
        .followedBy(hrvPoints.map((p) => p.y ?? 0.0)));
    final rhrMax = maxValue(rhrPoints.map((p) => p.y ?? 0.0));
    final rhrMin = minValue(rhrPoints.map((p) => p.y ?? 0.0));
    final stepsMax = maxValue(stepsPoints.map((p) => p.y ?? 0.0));
    final stepsMin = minValue(stepsPoints.map((p) => p.y ?? 0.0));

    final plotBands = buildPlotBands(
      focusDate: focusDate,
      journals: controller.journals,
      color: Theme.of(context).colorScheme.secondary,
    );

    final chartSpacing = widget.isMobile ? 12.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Zoom/Pan instructions for better UX
        if (!widget.isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app,
                  size: 16,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  'Pinch to zoom, drag to pan, double-tap to reset',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        Expanded(
          child: MetricChart(
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
            isMobile: widget.isMobile,
            isTablet: widget.isTablet,
          ),
        ),
        SizedBox(height: chartSpacing),
        Expanded(
          child: MetricChart(
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
            isMobile: widget.isMobile,
            isTablet: widget.isTablet,
          ),
        ),
        SizedBox(height: chartSpacing),
        Expanded(
          child: MetricChart(
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
            isMobile: widget.isMobile,
            isTablet: widget.isTablet,
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
