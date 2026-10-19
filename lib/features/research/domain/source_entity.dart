/// Domain entity representing a captured or extracted webpage source.
class SourceEntity {
  final int? id;
  final Uri url;
  final String title;
  final Uri? canonicalUrl;
  final String? author;
  final String? publishedDate;
  final List<String> headings;
  final String? extractedText;
  final DateTime capturedAt;

  SourceEntity({
    this.id,
    required this.url,
    required this.title,
    this.canonicalUrl,
    this.author,
    this.publishedDate,
    List<String>? headings,
    this.extractedText,
    DateTime? capturedAt,
  })  : headings = List.unmodifiable(headings ?? const []),
        capturedAt = capturedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'url': url.toString(),
      'title': title.trim().isEmpty ? (url.host.isEmpty ? url.toString() : url.host) : title.trim(),
      'canonical_url': canonicalUrl?.toString(),
      'author': author?.trim(),
      'published_date': publishedDate?.trim(),
      'headings': headings.join('\n'),
      'extracted_text': extractedText,
      'captured_at': capturedAt.millisecondsSinceEpoch,
    };
  }

  factory SourceEntity.fromMap(Map<String, dynamic> map) {
    final rawHeadings = map['headings'] as String?;
    final headingsList = rawHeadings != null && rawHeadings.isNotEmpty
        ? rawHeadings.split('\n').where((h) => h.trim().isNotEmpty).toList()
        : <String>[];

    return SourceEntity(
      id: map['id'] as int?,
      url: Uri.parse(map['url'] as String),
      title: map['title'] as String,
      canonicalUrl: map['canonical_url'] != null ? Uri.tryParse(map['canonical_url'] as String) : null,
      author: map['author'] as String?,
      publishedDate: map['published_date'] as String?,
      headings: headingsList,
      extractedText: map['extracted_text'] as String?,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
    );
  }

  SourceEntity copyWith({
    int? id,
    Uri? url,
    String? title,
    Uri? canonicalUrl,
    String? author,
    String? publishedDate,
    List<String>? headings,
    String? extractedText,
    DateTime? capturedAt,
  }) {
    return SourceEntity(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      author: author ?? this.author,
      publishedDate: publishedDate ?? this.publishedDate,
      headings: headings ?? this.headings,
      extractedText: extractedText ?? this.extractedText,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }
}
