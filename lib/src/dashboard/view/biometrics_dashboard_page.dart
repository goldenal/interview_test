import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/models/biometric_sample.dart';
import '../domain/range_option.dart';
import '../services/rolling_statistics.dart';
import 'biometrics_dashboard_controller.dart';
import 'widgets/charts_section.dart';
import 'widgets/empty_state.dart';
import 'widgets/error_state.dart';
import 'widgets/loading_state.dart';

/// Main biometrics dashboard page with responsive design
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
                return const LoadingState();
              case DashboardStatus.error:
                return ErrorState(
                  message: controller.errorMessage ?? 'Unexpected error',
                  onRetry: controller.retry,
                );
              case DashboardStatus.empty:
                return const EmptyState();
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
        // Enhanced responsive breakpoints
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final isDesktop = constraints.maxWidth >= 1024;

        // Better height detection for scrollable content
        final shouldScroll = constraints.maxHeight < 800 || isMobile;

        final EdgeInsets padding = EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (isTablet ? 24 : 32),
          vertical: isMobile ? 16 : (isTablet ? 20 : 24),
        );

        final content = _DashboardContent(
          controller: controller,
          isMobile: isMobile,
          isTablet: isTablet,
          isDesktop: isDesktop,
          shouldScroll: shouldScroll,
          availableHeight: constraints.maxHeight,
        );

        if (shouldScroll) {
          return SingleChildScrollView(
            padding: padding,
            child: content,
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
    required this.isMobile,
    required this.isTablet,
    required this.isDesktop,
    required this.shouldScroll,
    required this.availableHeight,
  });

  final BiometricsDashboardController controller;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;
  final bool shouldScroll;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusSample = controller.sampleNearestTo(controller.focusDate);
    final stats = controller.statsNearestTo(controller.focusDate);

    // Calculate optimal chart height based on screen size and content
    final double chartSectionHeight = _calculateChartHeight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeaderRow(
          controller: controller,
          isMobile: isMobile,
          isTablet: isTablet,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _RangeSelector(
          controller: controller,
          isMobile: isMobile,
          isTablet: isTablet,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _FocusSummaryCard(
          sample: focusSample,
          stats: stats,
          isMobile: isMobile,
          isTablet: isTablet,
        ),
        SizedBox(height: isMobile ? 16 : 20),
        if (shouldScroll)
          SizedBox(
            height: chartSectionHeight,
            child: ChartsSection(
              controller: controller,
              isMobile: isMobile,
              isTablet: isTablet,
            ),
          )
        else
          Expanded(
            child: ChartsSection(
              controller: controller,
              isMobile: isMobile,
              isTablet: isTablet,
            ),
          ),
        SizedBox(height: isMobile ? 12 : 16),
        if (controller.journals.isNotEmpty)
          _JournalList(
            journals: controller.journals,
            isMobile: isMobile,
          ),
        if (controller.journals.isNotEmpty) SizedBox(height: isMobile ? 12 : 16),
        Padding(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 4),
          child: Text(
            isMobile
                ? 'Tap charts to sync metrics.'
                : 'Pan or pinch to explore. Hover or tap charts to sync metrics.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: isMobile ? 12 : null,
            ),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
          ),
        ),
      ],
    );
  }

  double _calculateChartHeight() {
    if (isMobile) {
      // Mobile: each chart gets about 200-250px, total ~700px
      return 700;
    } else if (isTablet) {
      // Tablet: slightly larger charts
      return 850;
    } else {
      // Desktop: full experience
      return 900;
    }
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.controller,
    required this.isMobile,
    required this.isTablet,
  });

  final BiometricsDashboardController controller;
  final bool isMobile;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mobile: Stack vertically for better readability
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Biometrics Overview',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'HRV, resting HR, and activity trends with journal context.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _LargeDatasetToggle(
            value: controller.simulateLargeDataset,
            onChanged: (value) => controller.toggleLargeDataset(value),
            isMobile: isMobile,
            isTablet: isTablet,
          ),
        ],
      );
    }

    // Tablet & Desktop: Horizontal layout
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
          isMobile: isMobile,
          isTablet: isTablet,
        ),
      ],
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.controller,
    required this.isMobile,
    required this.isTablet,
  });

  final BiometricsDashboardController controller;
  final bool isMobile;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Range',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: isMobile ? 15 : null,
              ),
        ),
        SegmentedButton<RangeOption>(
          segments: RangeOption.values
              .map(
                (option) => ButtonSegment<RangeOption>(
                  value: option,
                  label: Text(
                    option.label,
                    style: TextStyle(fontSize: isMobile ? 13 : null),
                  ),
                ),
              )
              .toList(),
          selected: <RangeOption>{controller.range},
          showSelectedIcon: false,
          style: ButtonStyle(
            padding: WidgetStateProperty.resolveWith(
              (states) => EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : (isTablet ? 16 : 20),
                vertical: isMobile ? 8 : 10,
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
    required this.isMobile,
    required this.isTablet,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isMobile;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mobile: Horizontal compact layout
    if (isMobile) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Large dataset',
            style: theme.textTheme.labelMedium?.copyWith(fontSize: 13),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      );
    }

    // Tablet & Desktop: Vertical layout with description
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
            const SizedBox(width: 8),
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
    required this.isMobile,
    required this.isTablet,
  });

  final BiometricSample? sample;
  final RollingStatsPoint? stats;
  final bool isMobile;
  final bool isTablet;

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
        padding: EdgeInsets.all(isMobile ? 14 : (isTablet ? 16 : 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 15 : null,
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            Wrap(
              spacing: isMobile ? 10 : 16,
              runSpacing: isMobile ? 10 : 12,
              children: [
                _MetricChip(
                  label: 'HRV',
                  value: hrvValue,
                  isMobile: isMobile,
                ),
                _MetricChip(
                  label: 'Resting HR',
                  value: rhrValue,
                  isMobile: isMobile,
                ),
                _MetricChip(
                  label: 'Steps',
                  value: stepsValue,
                  isMobile: isMobile,
                ),
                _MetricChip(
                  label: 'Sleep score',
                  value: sleepValue,
                  isMobile: isMobile,
                ),
                _MetricChip(
                  label: '7d mean ±1σ',
                  value: statsLabel,
                  isMobile: isMobile,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.isMobile,
  });

  final String label;
  final String value;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: isMobile ? 11 : null,
            ),
          ),
          SizedBox(height: isMobile ? 3 : 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 14 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalList extends StatelessWidget {
  const _JournalList({
    required this.journals,
    required this.isMobile,
  });

  final List<dynamic> journals;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal Highlights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 15 : null,
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            for (final entry in journals)
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: isMobile ? 8 : 10,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${dateFormat.format(entry.date)} • Mood ${entry.mood}/5',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 13 : null,
                            ),
                          ),
                          SizedBox(height: isMobile ? 3 : 4),
                          Text(
                            entry.note,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: isMobile ? 13 : null,
                            ),
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
