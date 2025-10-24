class JournalEntry {
  JournalEntry({
    required this.date,
    required this.mood,
    required this.note,
  });

  final DateTime date;
  final int mood;
  final String note;

  static JournalEntry? fromJson(Map<String, dynamic> json) {
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

    final mood = json['mood'];
    final note = json['note'] as String? ?? '';
    final parsedMood = mood is num ? mood.toInt() : int.tryParse('$mood');

    if (parsedMood == null) {
      return null;
    }

    return JournalEntry(
      date: date,
      mood: parsedMood.clamp(0, 5),
      note: note,
    );
  }
}
