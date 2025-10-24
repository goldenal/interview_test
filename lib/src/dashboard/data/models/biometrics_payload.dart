import 'biometric_sample.dart';
import 'journal_entry.dart';

class BiometricsPayload {
  BiometricsPayload({
    required this.samples,
    required this.journals,
  });

  final List<BiometricSample> samples;
  final List<JournalEntry> journals;

  bool get isEmpty => samples.isEmpty;
}
