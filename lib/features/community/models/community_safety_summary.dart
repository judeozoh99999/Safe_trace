class CommunitySafetySummary {
  final String safetyLevel; // Safe, Moderate, Caution, Danger, Unknown
  final String summary;
  final List<String> keyConcerns;
  final int noteCount;
  final DateTime generatedAt;

  CommunitySafetySummary({
    required this.safetyLevel,
    required this.summary,
    required this.keyConcerns,
    required this.noteCount,
    required this.generatedAt,
  });

  factory CommunitySafetySummary.fromMap(Map<String, dynamic> map) {
    DateTime dt = DateTime.now();
    if (map['generated_at'] != null) {
      if (map['generated_at'] is String) {
        dt = DateTime.tryParse(map['generated_at']) ?? DateTime.now();
      } else if (map['generated_at'] is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(map['generated_at']);
      }
    }

    List<String> concerns = [];
    if (map['key_concerns'] != null && map['key_concerns'] is List) {
      concerns = (map['key_concerns'] as List).map((e) => e.toString()).toList();
    }

    return CommunitySafetySummary(
      safetyLevel: map['safety_level']?.toString() ?? 'Unknown',
      summary: map['summary']?.toString() ?? '',
      keyConcerns: concerns,
      noteCount: int.tryParse(map['note_count']?.toString() ?? '0') ?? 0,
      generatedAt: dt,
    );
  }
}
