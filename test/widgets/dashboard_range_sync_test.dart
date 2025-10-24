import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:interview_test/src/dashboard/data/models/biometric_sample.dart';
import 'package:interview_test/src/dashboard/data/models/biometrics_payload.dart';
import 'package:interview_test/src/dashboard/data/models/journal_entry.dart';
import 'package:interview_test/src/dashboard/data/repository/biometrics_repository.dart';
import 'package:interview_test/src/dashboard/view/biometrics_dashboard_controller.dart';
import 'package:interview_test/src/dashboard/view/biometrics_dashboard_page.dart';

class _FakeBiometricsRepository extends BiometricsRepository {
  _FakeBiometricsRepository(this._payload)
      : super(
          latencyMin: Duration.zero,
          latencyMax: Duration.zero,
          failureProbability: 0,
        );

  final BiometricsPayload _payload;

  @override
  Future<BiometricsPayload> fetchBiometrics({bool simulateLargeDataset = false}) async {
    return _payload;
  }
}

void main() {
  group('Biometrics dashboard interactions', () {
    late List<BiometricSample> samples;
    late List<JournalEntry> journals;

    setUp(() {
      final start = DateTime(2025, 1, 1);
      samples = List.generate(120, (index) {
        final date = start.add(Duration(days: index));
        return BiometricSample(
          date: date,
          hrv: 50 + (index % 5) * 1.5,
          rhr: 60 + (index % 4),
          steps: 7000 + index * 20,
          sleepScore: 75 + (index % 3),
        );
      });
      journals = [
        JournalEntry(date: start.add(const Duration(days: 15)), mood: 4, note: 'Tempo run'),
        JournalEntry(date: start.add(const Duration(days: 45)), mood: 2, note: 'Late night'),
      ];
    });

    testWidgets('range switch updates view and tapping chart syncs focus', (tester) async {
      final payload = BiometricsPayload(samples: samples, journals: journals);
      final repository = _FakeBiometricsRepository(payload);

      await tester.pumpWidget(
        ChangeNotifierProvider<BiometricsDashboardController>(
          create: (_) => BiometricsDashboardController(repository: repository)..load(),
          child: const MaterialApp(
            home: Scaffold(
              body: BiometricsDashboardPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(BiometricsDashboardPage));
      final controller = Provider.of<BiometricsDashboardController>(context, listen: false);
      final rangeController = controller.rangeController!;

      DateTime _asDate(dynamic value) => value as DateTime;

      // Initial range should be 90 days wide (end inclusive).
      var start = _asDate(rangeController.start);
      var end = _asDate(rangeController.end);
      expect(end.difference(start).inDays, 89);

      await tester.tap(find.text('7D'));
      await tester.pumpAndSettle();

      start = _asDate(rangeController.start);
      end = _asDate(rangeController.end);
      expect(end.difference(start).inDays, 6);
      expect(controller.focusDate, end);

      final chartFinder = find.byType(SfCartesianChart).first;
      final chartRect = tester.getRect(chartFinder);
      final tapPoint = Offset(chartRect.left + chartRect.width * 0.25, chartRect.center.dy);

      await tester.tapAt(tapPoint);
      await tester.pump(const Duration(milliseconds: 60));

      expect(controller.focusDate, isNotNull);
      final formatted = DateFormat('EEE, MMM d').format(controller.focusDate!);
      expect(find.text(formatted), findsOneWidget);
    });
  });
}
