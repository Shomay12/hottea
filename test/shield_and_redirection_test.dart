import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/features/browser/domain/browser_engine.dart';
import 'package:hottea/features/browser/domain/browser_tab.dart';
import 'package:hottea/features/browser/domain/hottea_shield_rules.dart';

void main() {
  group('HotTea Shield & Redirection Protections Unit Tests', () {
    test('Default HotTeaShieldConfig enables all protections for frictionless browsing', () {
      const config = HotTeaShieldConfig();
      expect(config.shieldEnabled, isTrue);
      expect(config.blockAdsAndTrackers, isTrue);
      expect(config.blockThirdPartyCookies, isTrue);
      expect(config.keepNavigationsInSameTab, isTrue);
      expect(config.defuseAntiAdblockAndGates, isTrue);
      expect(config.autoDismissCookieWalls, isTrue);
    });

    test('HotTeaShieldConfig serializes and deserializes from persistence map accurately', () {
      const original = HotTeaShieldConfig(
        shieldEnabled: true,
        blockAdsAndTrackers: true,
        blockThirdPartyCookies: false,
        keepNavigationsInSameTab: true,
        defuseAntiAdblockAndGates: true,
        autoDismissCookieWalls: false,
      );

      final map = original.toPersistenceMap();
      expect(map['shield_enabled'], equals('true'));
      expect(map['block_third_party_cookies'], equals('false'));
      expect(map['auto_dismiss_cookie_walls'], equals('false'));

      final restored = HotTeaShieldConfig.fromPersistenceMap(map);
      expect(restored.shieldEnabled, isTrue);
      expect(restored.blockAdsAndTrackers, isTrue);
      expect(restored.blockThirdPartyCookies, isFalse);
      expect(restored.keepNavigationsInSameTab, isTrue);
      expect(restored.defuseAntiAdblockAndGates, isTrue);
      expect(restored.autoDismissCookieWalls, isFalse);
    });

    test('HotTeaShieldRules accurately detects ad and tracking networks', () {
      final adUrls = [
        Uri.parse('https://ad.doubleclick.net/ddm/trackclk/N1234'),
        Uri.parse('https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'),
        Uri.parse('https://serve.popads.net/serve.js'),
        Uri.parse('https://adsterra.com/tag.js'),
        Uri.parse('https://syndication.exoclick.com/splash.php'),
        Uri.parse('https://trc.taboola.com/libtrc/unip/123/tfa.js'),
        Uri.parse('https://trafficjunky.com/delivery/impressions.php'),
      ];

      for (final url in adUrls) {
        expect(
          HotTeaShieldRules.isAdOrTracker(url),
          isTrue,
          reason: 'Expected $url to be flagged as ad or tracker',
        );
      }
    });

    test('HotTeaShieldRules never flags legitimate destination websites or search queries', () {
      final legitimateUrls = [
        Uri.parse('https://flutter.dev'),
        Uri.parse('https://docs.flutter.dev/get-started'),
        Uri.parse('https://google.com/search?q=hottea+browser'),
        Uri.parse('https://github.com/Shomay12/hottea'),
        Uri.parse('https://en.wikipedia.org/wiki/Dart_(programming_language)'),
        Uri.parse('https://duckduckgo.com/?q=privacy+browser'),
        Uri.parse('https://news.ycombinator.com'),
        Uri.parse('https://net52.cc/mobile/home?partner=doubleclick.net'),
        Uri.parse('https://net77.cc/player?src=adservice.google.com'),
      ];

      for (final url in legitimateUrls) {
        expect(
          HotTeaShieldRules.isAdOrTracker(url),
          isFalse,
          reason: 'Legitimate website $url must never be blocked',
        );
      }
    });

    test('ContentBlockers list contains network block and css hiding rules', () {
      final blockers = HotTeaShieldRules.getContentBlockers();
      expect(blockers.isNotEmpty, isTrue);
      expect(blockers.length, greaterThanOrEqualTo(2));
    });

    test('Shield UserScript includes Anti-Adblock defuser, same-tab redirection, and ad-gate cleaner', () {
      final script = HotTeaShieldRules.getShieldUserScript();
      expect(script.source, contains('canRunAds'));
      expect(script.source, contains('adsbygoogle'));
      expect(script.source, contains('window.open = function'));
      expect(script.source, contains('defuseGatesAndOverlays'));
      expect(script.source, contains('we need support'));
      expect(script.source, contains('open 1 ads per day'));
      expect(script.source, contains('mockWindow'));
      expect(script.source, contains('localStorage.setItem'));
      expect(script.source, contains('window.location.href = parsed.href'));
      expect(script.source, contains('clientHeight'));
      expect(script.source, contains('sendBeacon'));
      expect(script.source, contains('cdn-cgi/challenge-platform'));
      expect(script.source, contains('XMLHttpRequest'));
    });

    test('Anti-bot challenge verification URLs and domains are never blocked as ads', () {
      final verificationUrls = [
        Uri.parse('https://net77.cc/verify2?__cf_chl_rt_tk=Alyuk5bvzu5UTLaTlifGcFIELfdm6sZYjPEIAC'),
        Uri.parse('https://challenges.cloudflare.com/turnstile/v0/api.js'),
        Uri.parse('https://example.com/cdn-cgi/challenge-platform/h/b/flow/ov1/'),
        Uri.parse('https://hcaptcha.com/checksiteconfig'),
        Uri.parse('https://www.google.com/recaptcha/api.js'),
      ];

      for (final url in verificationUrls) {
        expect(
          HotTeaShieldRules.isAdOrTracker(url),
          isFalse,
          reason: 'Verification challenge URL $url must never be blocked as an ad',
        );
      }
    });

    test('Third-party cookie blocker exempts verification challenge providers on Apple platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final blockers = HotTeaShieldRules.getContentBlockers();
        final cookieBlockers = blockers.where(
          (b) => b.action.type == ContentBlockerActionType.BLOCK_COOKIES,
        );

        expect(cookieBlockers.isNotEmpty, isTrue);
        for (final blocker in cookieBlockers) {
          expect(blocker.trigger.unlessDomain, isNotNull);
          expect(blocker.trigger.unlessDomain, contains('*.cloudflare.com'));
          expect(blocker.trigger.unlessDomain, contains('*.challenges.cloudflare.com'));
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('MockBrowserEngine enforces Shield rules: blocks ad networks and allows legitimate sites', () async {
      final engine = MockBrowserEngine();
      await engine.initialize(initialUrl: Uri.parse('about:blank'));

      // Attempt navigation to ad network
      await engine.loadUrl(Uri.parse('https://serve.popads.net/banner'));
      expect(engine.currentError, isNotNull);
      expect(engine.currentError!.message, contains('Blocked by HotTea Shield'));

      // Legitimate navigation succeeds
      await engine.loadUrl(Uri.parse('https://docs.flutter.dev'));
      expect(engine.currentError, isNull);
      expect(engine.currentUrl, equals(Uri.parse('https://docs.flutter.dev')));

      // When shield is disabled, ad navigation is permitted
      engine.updateShieldConfig(const HotTeaShieldConfig(shieldEnabled: false));
      await engine.loadUrl(Uri.parse('https://serve.popads.net/banner'));
      expect(engine.currentError, isNull);
      expect(engine.currentUrl, equals(Uri.parse('https://serve.popads.net/banner')));
    });

    test('Same-Tab Redirection invariant: Sequential navigations stay inside the active tab', () async {
      final engine = MockBrowserEngine();
      final tab = BrowserTab(
        id: 'test_tab_redirection',
        engine: engine,
      );

      // Start at initial site
      await tab.loadUrl(Uri.parse('https://example.com/start'));
      expect(tab.currentUrl, equals(Uri.parse('https://example.com/start')));

      // Server / link redirect to intermediate URL
      await tab.loadUrl(Uri.parse('https://example.com/redirect-gate?target=final'));
      expect(tab.currentUrl, equals(Uri.parse('https://example.com/redirect-gate?target=final')));

      // Final destination URL in the SAME tab
      await tab.loadUrl(Uri.parse('https://example.com/final-destination'));
      expect(tab.currentUrl, equals(Uri.parse('https://example.com/final-destination')));
      expect(tab.canGoBack, isTrue);
    });
  });
}
