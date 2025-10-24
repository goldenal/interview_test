# Biometrics Dashboard

An interactive Flutter Web dashboard that visualises HRV, resting heart rate, and steps data with journal context. It is designed to showcase resilient data loading, responsive UX, and performant chart rendering under large data volumes.

## Getting Started

- `flutter pub get`
- `flutter run -d chrome` (app boots with simulated 700–1200 ms asset latency and ~10 % random failures; use the retry control to recover)
- `flutter test` to run unit and widget coverage

## Features

- Three synchronised `SfCartesianChart` time-series with shared crosshair, pan/zoom, and 7 / 30 / 90 day range controls.
- 7-day rolling HRV band (mean ±1σ) plus journal annotations that surface mood/notes on tap.
- Dedicated summary card and shared tooltip behaviour bound to a common `focusDate`.
- Error, loading skeleton, and empty states that react to injected latency/failure.
- Responsive layout tested down to 375 px and Material 3 dark mode support.
- “Large dataset” toggle that expands to 10 k+ samples to demonstrate scaling.

## Architecture Highlights

- `BiometricsRepository` loads JSON assets with injected latency/failure and optional large dataset synthesis.
- `BiometricsDashboardController` (Provider/ChangeNotifier) owns range/focus state, range decimation, and shared `RangeController` for cross-chart viewport synchronisation.
- Chart pipeline lives under `lib/src/dashboard/view`, with reusable `_MetricChart` widget, rolling statistics service, and decimation service.

```
lib/
  src/
    app/                // app shell & themes
    dashboard/
      data/             // models + repository
      services/         // decimator & rolling stats
      view/             // controller + widgets
    shared/             // theming helpers
```

## Testing

- `test/services/time_series_decimator_test.dart` ensures the LTTB decimator respects thresholds while retaining extremes.
- `test/widgets/dashboard_range_sync_test.dart` verifies range switches keep charts in sync and crosshair focus updates.

## Perf Note

- Implemented Largest-Triangle-Three-Buckets downsampling (cap ~900 points) for 30 / 90-day windows and the 10 k sample toggle. This keeps chart rebuilds within the 16 ms frame budget on Chrome (observed 8–12 ms via Flutter DevTools profile while panning). The shared `RangeController` prevents redundant redraws across the three charts.
