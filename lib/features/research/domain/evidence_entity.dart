/// Domain entity representing a captured verbatim evidence passage.
///
/// Evidence records preserve original source text without rewriting or AI summarization.
class EvidenceEntity {
  final int? id;
  final int? sourceId;
  final Uri sourceUrl;
  final String sourceTitle;
  final String passage;
  final String? contextHeading;
  final String? annotation;
  final List<String> tags;
  final String? topic;
  final DateTime capturedAt;

  EvidenceEntity({
    this.id,
    this.sourceId,
    required this.sourceUrl,
    required this.sourceTitle,
    required this.passage,
    this.contextHeading,
    this.annotation,
    List<String>? tags,
    this.topic,
    DateTime? capturedAt,
  })  : tags = List.unmodifiable(tags?.map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? const []),
        capturedAt = capturedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'source_id': sourceId,
      'source_url': sourceUrl.toString(),
      'source_title': sourceTitle.trim().isEmpty
          ? (sourceUrl.host.isEmpty ? sourceUrl.toString() : sourceUrl.host)
          : sourceTitle.trim(),
      'passage': passage.trim(),
      'context_heading': contextHeading?.trim(),
      'annotation': annotation?.trim(),
      'tags': tags.join(','),
      'topic': topic?.trim(),
      'captured_at': capturedAt.millisecondsSinceEpoch,
    };
  }

  String get tagsFormatted => tags.join(', ');

  factory EvidenceEntity.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'] as String?;
    final tagsList = rawTags != null && rawTags.isNotEmpty
        ? rawTags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];

    DateTime parsedCapturedAt;
    final rawCaptured = map['captured_at'];
    if (rawCaptured is int) {
      parsedCapturedAt = DateTime.fromMillisecondsSinceEpoch(rawCaptured);
    } else if (rawCaptured is String) {
      parsedCapturedAt = DateTime.tryParse(rawCaptured) ?? DateTime.now();
    } else {
      parsedCapturedAt = DateTime.now();
    }

    return EvidenceEntity(
      id: map['id'] as int?,
      sourceId: map['source_id'] as int?,
      sourceUrl: Uri.parse(map['source_url'] as String),
      sourceTitle: map['source_title'] as String,
      passage: map['passage'] as String,
      contextHeading: map['context_heading'] as String?,
      annotation: map['annotation'] as String?,
      tags: tagsList,
      topic: map['topic'] as String?,
      capturedAt: parsedCapturedAt,
    );
  }

  EvidenceEntity copyWith({
    int? id,
    int? sourceId,
    Uri? sourceUrl,
    String? sourceTitle,
    String? passage,
    String? contextHeading,
    String? annotation,
    List<String>? tags,
    String? topic,
    DateTime? capturedAt,
  }) {
    return EvidenceEntity(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      passage: passage ?? this.passage,
      contextHeading: contextHeading ?? this.contextHeading,
      annotation: annotation ?? this.annotation,
      tags: tags ?? this.tags,
      topic: topic ?? this.topic,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}
