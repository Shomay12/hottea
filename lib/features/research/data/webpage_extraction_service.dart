import 'dart:convert';
import '../../browser/domain/browser_engine.dart';
import '../domain/evidence_entity.dart';
import '../domain/source_entity.dart';
import '../domain/webpage_extraction.dart';

/// Service responsible for on-device extraction of structured webpage metadata,
/// readable article text, and user-selected passages from a [BrowserEngine].
///
/// Invariant: 100% on-device execution. Never transmits extracted DOM content
/// to external networks or AI providers during extraction.
class WebpageExtractionService {
  /// Maximum text length extracted from a single document to protect memory and UI responsiveness.
  static const int maxExtractedCharacters = 50000;

  /// The JavaScript payload injected into the page to extract metadata, headings, and clean text.
  static const String _domExtractorScript = r'''
(function() {
  try {
    var result = {
      title: document.title || '',
      canonicalUrl: '',
      author: '',
      publishedDate: '',
      headings: [],
      readableText: '',
      selection: ''
    };

    // 1. Canonical URL
    var canonicalLink = document.querySelector('link[rel="canonical"]');
    if (canonicalLink && canonicalLink.href) {
      result.canonicalUrl = canonicalLink.href;
    }

    // 2. Author metadata
    var authorMeta = document.querySelector('meta[name="author"]') ||
                     document.querySelector('meta[property="article:author"]') ||
                     document.querySelector('meta[name="dc.creator"]');
    if (authorMeta && authorMeta.content) {
      result.author = authorMeta.content.trim();
    }

    // 3. Publication Date
    var dateMeta = document.querySelector('meta[property="article:published_time"]') ||
                   document.querySelector('meta[name="date"]') ||
                   document.querySelector('meta[name="dc.date"]');
    if (dateMeta && dateMeta.content) {
      result.publishedDate = dateMeta.content.trim();
    } else {
      var timeElem = document.querySelector('time[datetime]');
      if (timeElem && timeElem.getAttribute('datetime')) {
        result.publishedDate = timeElem.getAttribute('datetime').trim();
      }
    }

    // 4. Headings (h1, h2, h3)
    var headingNodes = document.querySelectorAll('h1, h2, h3');
    for (var i = 0; i < headingNodes.length && i < 40; i++) {
      var hText = headingNodes[i].innerText || headingNodes[i].textContent || '';
      hText = hText.trim();
      if (hText.length > 0 && hText.length < 200) {
        result.headings.push(hText);
      }
    }

    // 5. Active User Selection
    var sel = window.getSelection();
    if (sel && sel.toString) {
      result.selection = sel.toString().trim();
    }

    // 6. Readable main body text
    var mainContainer = document.querySelector('article') ||
                        document.querySelector('main') ||
                        document.querySelector('[role="main"]') ||
                        document.body;

    if (mainContainer) {
      // Clone to remove script/style/nav noise without modifying DOM
      var clone = mainContainer.cloneNode(true);
      var noisySelectors = ['script', 'style', 'noscript', 'nav', 'header', 'footer', 'iframe', 'svg'];
      for (var s = 0; s < noisySelectors.length; s++) {
        var noisy = clone.querySelectorAll(noisySelectors[s]);
        for (var n = 0; n < noisy.length; n++) {
          noisy[n].remove();
        }
      }
      var text = clone.innerText || clone.textContent || '';
      // Normalize whitespace
      result.readableText = text.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
    }

    return JSON.stringify(result);
  } catch (err) {
    return JSON.stringify({ error: String(err) });
  }
})();
''';

  /// Exposes the DOM extraction script for test inspection.
  static String get domExtractorScript => _domExtractorScript;

  /// Parses the raw JSON string payload returned by [_domExtractorScript].
  WebpageExtractionResult parseExtractionPayload(
    String? jsResult, {
    required Uri currentUrl,
    required String fallbackTitle,
  }) {
    if (jsResult == null || !jsResult.trim().startsWith('{')) {
      return WebpageExtractionResult.failed(
        error: 'Extraction result parsing failed: invalid payload format',
        url: currentUrl,
        title: fallbackTitle,
      );
    }

    try {
      final parsed = jsonDecode(jsResult) as Map<String, dynamic>;

      if (parsed.containsKey('error')) {
        return WebpageExtractionResult.failed(
          error: 'In-page script error: ${parsed['error']}',
          url: currentUrl,
          title: fallbackTitle,
        );
      }

      final extractedTitle = (parsed['title'] as String?)?.trim();
      final finalTitle = (extractedTitle != null && extractedTitle.isNotEmpty)
          ? extractedTitle
          : fallbackTitle;

      final canonicalStr = parsed['canonicalUrl'] as String?;
      final canonicalUrl = (canonicalStr != null && canonicalStr.isNotEmpty)
          ? Uri.tryParse(canonicalStr)
          : null;

      final author = (parsed['author'] as String?)?.trim();
      final publishedDate = (parsed['publishedDate'] as String?)?.trim();
      final headingsList = (parsed['headings'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];

      var readableText = (parsed['readableText'] as String? ?? parsed['text'] as String?)?.trim() ?? '';
      if (readableText.length > maxExtractedCharacters) {
        readableText = '${readableText.substring(0, maxExtractedCharacters)}\n\n[Content truncated at 50,000 characters...]';
      }

      final selection = (parsed['selection'] as String?)?.trim();

      if (readableText.isEmpty) {
        return WebpageExtractionResult.empty(
          url: currentUrl,
          title: finalTitle,
          message: 'Webpage body contained no readable text.',
        );
      }

      final source = SourceEntity(
        url: currentUrl,
        title: finalTitle,
        canonicalUrl: canonicalUrl,
        author: (author != null && author.isNotEmpty) ? author : null,
        publishedDate: (publishedDate != null && publishedDate.isNotEmpty) ? publishedDate : null,
        headings: headingsList,
        extractedText: readableText,
        capturedAt: DateTime.now(),
      );

      return WebpageExtractionResult.success(
        source: source,
        activeSelection: selection,
      );
    } catch (e) {
      return WebpageExtractionResult.failed(
        error: 'Extraction result parsing failed: $e',
        url: currentUrl,
        title: fallbackTitle,
      );
    }
  }

  /// Extracts structured page content and active selection from [engine].
  Future<WebpageExtractionResult> extractFromEngine(BrowserEngine engine) async {
    final currentUrl = engine.currentUrl;
    if (currentUrl == null || currentUrl.toString().trim().isEmpty) {
      return WebpageExtractionResult.invalidTarget('No active webpage URL to extract.');
    }

    // Check for about:blank or special internal pages
    if (currentUrl.scheme == 'about' && currentUrl.path != 'blank') {
      return WebpageExtractionResult.invalidTarget('Cannot extract content from internal browser page (${currentUrl.toString()}).');
    }

    final fallbackTitle = engine.currentTitle.isNotEmpty ? engine.currentTitle : currentUrl.toString();

    // Check engine capabilities
    if (!engine.capabilities.supportsScriptInjection && !engine.capabilities.supportsDomExtraction) {
      return WebpageExtractionResult.restricted(
        url: currentUrl,
        title: fallbackTitle,
        message: 'Current platform browser engine does not support DOM script injection.',
      );
    }

    try {
      final jsResult = await engine.evaluateJavascript(_domExtractorScript);

      if (jsResult != null && jsResult is String && jsResult.trim().startsWith('{')) {
        return parseExtractionPayload(jsResult, currentUrl: currentUrl, fallbackTitle: fallbackTitle);
      }

      // Fallback to extractPageContent() if evaluateJavascript did not return JSON
      final rawContent = await engine.extractPageContent();
      if (rawContent != null && rawContent.trim().isNotEmpty) {
        var cleanText = rawContent.trim();
        if (cleanText.length > maxExtractedCharacters) {
          cleanText = '${cleanText.substring(0, maxExtractedCharacters)}\n\n[Content truncated at 50,000 characters...]';
        }

        final source = SourceEntity(
          url: currentUrl,
          title: fallbackTitle,
          extractedText: cleanText,
          capturedAt: DateTime.now(),
        );

        return WebpageExtractionResult.success(source: source);
      }

      return WebpageExtractionResult.empty(
        url: currentUrl,
        title: fallbackTitle,
        message: 'No readable content returned by browser engine.',
      );
    } catch (e) {
      return WebpageExtractionResult.failed(
        error: 'Webpage extraction failed: $e',
        url: currentUrl,
        title: fallbackTitle,
      );
    }
  }

  /// Parses a manually clipped passage or selection into an [EvidenceEntity].
  EvidenceEntity clipPassage({
    required SourceEntity source,
    required String passage,
    String? contextHeading,
    String? annotation,
    List<String>? tags,
    String? topic,
  }) {
    if (passage.trim().isEmpty) {
      throw ArgumentError('Captured evidence passage cannot be empty.');
    }

    return EvidenceEntity(
      sourceId: source.id,
      sourceUrl: source.canonicalUrl ?? source.url,
      sourceTitle: source.title,
      passage: passage.trim(),
      contextHeading: contextHeading?.trim(),
      annotation: annotation?.trim(),
      tags: tags,
      topic: topic?.trim(),
      capturedAt: DateTime.now(),
    );
  }
}
