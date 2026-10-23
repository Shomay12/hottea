import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/features/browser/domain/url_cleaner.dart';
import 'package:hottea/features/browser/domain/shield_stats.dart';
import 'package:hottea/features/browser/domain/hottea_shield_rules.dart';

void main() {
  group('Brave Parity: UrlCleaner Tests', () {
    test('UrlCleaner strips Google, Meta, Twitter, and general marketing tracking parameters', () {
      final dirtyUrl = Uri.parse(
        'https://example.com/product'
        '?utm_source=newsletter'
        '&utm_medium=email'
        '&utm_campaign=summer_sale'
        '&fbclid=IwAR123456789'
        '&gclid=CjwKCAjw'
        '&twclid=12345'
        '&msclkid=abcd'
        '&mc_eid=9876'
        '&item_id=42',
      );

      final cleaned = UrlCleaner.stripTrackingParameters(dirtyUrl);

      // Essential non-tracking query parameter is preserved
      expect(cleaned.queryParameters['item_id'], equals('42'));

      // All marketing tokens are stripped
      expect(cleaned.queryParameters.containsKey('utm_source'), isFalse);
      expect(cleaned.queryParameters.containsKey('utm_medium'), isFalse);
      expect(cleaned.queryParameters.containsKey('utm_campaign'), isFalse);
      expect(cleaned.queryParameters.containsKey('fbclid'), isFalse);
      expect(cleaned.queryParameters.containsKey('gclid'), isFalse);
      expect(cleaned.queryParameters.containsKey('twclid'), isFalse);
      expect(cleaned.queryParameters.containsKey('msclkid'), isFalse);
      expect(cleaned.queryParameters.containsKey('mc_eid'), isFalse);
    });

    test('UrlCleaner preserves clean URLs without queries or tracking', () {
      final cleanUrl = Uri.parse('https://flutter.dev/docs/get-started');
      expect(UrlCleaner.clean(cleanUrl), equals(cleanUrl));

      final nonTrackingQuery = Uri.parse('https://example.com/search?q=hottea+browser&page=2');
      expect(UrlCleaner.clean(nonTrackingQuery), equals(nonTrackingQuery));
    });

    test('UrlCleaner unwraps Google AMP URLs to publisher canonical URLs (Brave De-AMP)', () {
      final googleAmpUrl = Uri.parse('https://www.google.com/amp/s/theverge.com/2026/10/24/brave-ai-browser');
      final deAmped = UrlCleaner.deAmp(googleAmpUrl);

      expect(deAmped.scheme, equals('https'));
      expect(deAmped.host, equals('theverge.com'));
      expect(deAmped.path, equals('/2026/10/24/brave-ai-browser'));
    });

    test('UrlCleaner unwraps ampproject.org CDN links', () {
      final cdnAmpUrl = Uri.parse('https://example-com.cdn.ampproject.org/c/s/example.com/article/123');
      final deAmped = UrlCleaner.deAmp(cdnAmpUrl);

      expect(deAmped.scheme, equals('https'));
      expect(deAmped.host, equals('example.com'));
      expect(deAmped.path, equals('/article/123'));
    });
  });

  group('Brave Parity: ShieldStats & Metrics Tests', () {
    test('ShieldStats accurately estimates bandwidth and time saved', () {
      const stats = ShieldStats(
        trackersBlockedOnPage: 12,
        totalTrackersBlocked: 50,
      );

      // 50 trackers * 50KB = 2,560,000 bytes (~2.4 MB)
      expect(stats.estimatedBandwidthSavedBytes, equals(50 * 51200));
      expect(stats.formattedBandwidthSaved, contains('MB'));

      // 50 trackers * 50ms = 2500ms (2.5s)
      expect(stats.estimatedTimeSavedMs, equals(2500));
      expect(stats.formattedTimeSaved, equals('2.5s'));
    });

    test('HotTeaShieldConfig per-site domain exceptions (Shields UP / DOWN)', () {
      const config = HotTeaShieldConfig(
        shieldEnabled: true,
        disabledDomains: {'broken-site.org', 'internal-corp.net'},
      );

      expect(config.isShieldEnabledForHost('flutter.dev'), isTrue);
      expect(config.isShieldEnabledForHost('broken-site.org'), isFalse);
      expect(config.isShieldEnabledForHost('subdomain.broken-site.org'), isFalse);
      expect(config.isShieldEnabledForHost('internal-corp.net'), isFalse);
    });
  });
}
