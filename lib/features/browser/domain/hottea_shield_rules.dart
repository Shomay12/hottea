import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Configuration settings for HotTea Shield privacy and redirection engine.
class HotTeaShieldConfig {
  final bool shieldEnabled;
  final bool blockAdsAndTrackers;
  final bool blockThirdPartyCookies;
  final bool keepNavigationsInSameTab;
  final bool defuseAntiAdblockAndGates;
  final bool autoDismissCookieWalls;

  const HotTeaShieldConfig({
    this.shieldEnabled = true,
    this.blockAdsAndTrackers = true,
    this.blockThirdPartyCookies = true,
    this.keepNavigationsInSameTab = true,
    this.defuseAntiAdblockAndGates = true,
    this.autoDismissCookieWalls = true,
  });

  HotTeaShieldConfig copyWith({
    bool? shieldEnabled,
    bool? blockAdsAndTrackers,
    bool? blockThirdPartyCookies,
    bool? keepNavigationsInSameTab,
    bool? defuseAntiAdblockAndGates,
    bool? autoDismissCookieWalls,
  }) {
    return HotTeaShieldConfig(
      shieldEnabled: shieldEnabled ?? this.shieldEnabled,
      blockAdsAndTrackers: blockAdsAndTrackers ?? this.blockAdsAndTrackers,
      blockThirdPartyCookies: blockThirdPartyCookies ?? this.blockThirdPartyCookies,
      keepNavigationsInSameTab: keepNavigationsInSameTab ?? this.keepNavigationsInSameTab,
      defuseAntiAdblockAndGates: defuseAntiAdblockAndGates ?? this.defuseAntiAdblockAndGates,
      autoDismissCookieWalls: autoDismissCookieWalls ?? this.autoDismissCookieWalls,
    );
  }

  Map<String, String> toPersistenceMap() {
    return {
      'shield_enabled': shieldEnabled.toString(),
      'block_ads_trackers': blockAdsAndTrackers.toString(),
      'block_third_party_cookies': blockThirdPartyCookies.toString(),
      'same_tab_redirection': keepNavigationsInSameTab.toString(),
      'defuse_anti_adblock': defuseAntiAdblockAndGates.toString(),
      'auto_dismiss_cookie_walls': autoDismissCookieWalls.toString(),
    };
  }

  factory HotTeaShieldConfig.fromPersistenceMap(Map<String, String?> map) {
    return HotTeaShieldConfig(
      shieldEnabled: map['shield_enabled'] != 'false',
      blockAdsAndTrackers: map['block_ads_trackers'] != 'false',
      blockThirdPartyCookies: map['block_third_party_cookies'] != 'false',
      keepNavigationsInSameTab: map['same_tab_redirection'] != 'false',
      defuseAntiAdblockAndGates: map['defuse_anti_adblock'] != 'false',
      autoDismissCookieWalls: map['auto_dismiss_cookie_walls'] != 'false',
    );
  }
}

/// Rules, filters, and scripts powering HotTea Shield.
///
/// Ensures:
/// 1. Ad and tracker blocking without breaking website functional logic.
/// 2. Third-party cookie blocking while preserving first-party authentication/session cookies.
/// 3. Same-tab redirection lock: Links and redirects stay in the active tab without getting lost.
/// 4. Anti-adblock and fake redirection gate defusal: Servers believe tracking/redirection
///    acknowledged so content renders openly without friction or delay.
class HotTeaShieldRules {
  HotTeaShieldRules._();

  /// Known advertising, tracking, popunder, and clickjack host patterns.
  static final List<String> adAndTrackerDomains = [
    'doubleclick.net',
    'googlesyndication.com',
    'google-analytics.com',
    'adservice.google.com',
    'pagead2.googlesyndication.com',
    'criteo.com',
    'criteo.net',
    'adnxs.com',
    'amazon-adsystem.com',
    'taboola.com',
    'outbrain.com',
    'popads.net',
    'propellerads.com',
    'adsterra.com',
    'exoclick.com',
    'ad-maven.com',
    'trafficjunky.com',
    'trafficjunky.net',
    'monetag.com',
    'bidswitch.net',
    'moatads.com',
    'scorecardresearch.com',
    'hotjar.com',
    'clarity.ms',
    'mc.yandex.ru',
    'fbevents.js',
    'connect.facebook.net/en_US/fbevents.js',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'casalemedia.com',
    'zedo.com',
    'revcontent.com',
    'mgid.com',
    'hilltopads.net',
    'clickadu.com',
    'popcash.net',
  ];

  /// Combined regex matching ad and tracker network requests.
  static final RegExp adRegex = RegExp(
    r'(doubleclick\.net|googlesyndication\.com|google-analytics\.com|adservice\.google\.com|pagead2\.googlesyndication\.com|criteo\.com|criteo\.net|adnxs\.com|amazon-adsystem\.com|taboola\.com|outbrain\.com|popads\.net|propellerads\.com|adsterra\.com|exoclick\.com|ad-maven\.com|trafficjunky|monetag\.com|bidswitch\.net|moatads\.com|scorecardresearch\.com|hotjar\.com|clarity\.ms|fbevents\.js|rubiconproject\.com|pubmatic\.com|openx\.net|hilltopads|clickadu|popcash)',
    caseSensitive: false,
  );

  /// Checks if a given URI or host is an identified ad or tracking entity.
  static bool isAdOrTracker(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    for (final domain in adAndTrackerDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return adRegex.hasMatch(host);
  }

  /// Returns native WebKit/Chromium content blockers for network filtering and cosmetic element hiding.
  static List<ContentBlocker> getContentBlockers({HotTeaShieldConfig config = const HotTeaShieldConfig()}) {
    if (!config.shieldEnabled) return [];

    final List<ContentBlocker> blockers = [];

    if (config.blockAdsAndTrackers) {
      // 1. Discrete network blockers for known ad and tracker domains.
      // Individual substring filters compile instantaneously in WebKit DFA without regex complexity limits.
      for (final domain in adAndTrackerDomains) {
        blockers.add(
          ContentBlocker(
            trigger: ContentBlockerTrigger(
              urlFilter: '.*${RegExp.escape(domain)}.*',
            ),
            action: ContentBlockerAction(
              type: ContentBlockerActionType.BLOCK,
            ),
          ),
        );
      }

      // 2. Cosmetic ad banner & support gate hiding via CSS injection
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: '.*',
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.CSS_DISPLAY_NONE,
            selector: '.ad-banner, .advertisement, [id*="ad_banner"], [id*="google_ads"], [class*="sponsored-post"], ins.adsbygoogle, .taboola-ad, .outbrain-ad, #support_modal, #supportModal, .support-gate, .support-modal, #ad-gate, .ad-gate, #daily-ad, .daily-ad, #support-modal, .support-overlay',
          ),
        ),
      );
    }

    if (config.autoDismissCookieWalls) {
      // 3. Cosmetic hiding of intrusive cookie consent walls
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: '.*',
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.CSS_DISPLAY_NONE,
            selector: '#onetrust-consent-sdk, #onetrust-banner-sdk, .cookie-banner, .cookie-consent, [id*="cookie-notice"], .cmp-container, .fc-consent-root, #sp_message_container, .qc-cmp2-container',
          ),
        ),
      );
    }

    if (config.blockThirdPartyCookies &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      // 4. Block third-party tracking cookies on platforms supporting BLOCK_COOKIES,
      // using strict WebKit compliant wildcard format (*.domain) for challenge providers.
      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: '.*',
            loadType: [ContentBlockerTriggerLoadType.THIRD_PARTY],
            unlessDomain: [
              '*.cloudflare.com',
              '*.challenges.cloudflare.com',
              '*.hcaptcha.com',
              '*.google.com',
              '*.recaptcha.net',
            ],
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.BLOCK_COOKIES,
          ),
        ),
      );
    }

    return blockers;
  }

  /// Injected client-side script:
  /// - Defuses anti-adblock detection (spoofs adsbygoogle, canRunAds, analytics beacons, probe fetches, and XHR checks).
  /// - Neutralizes popups and keeps user in their active movie/content page without hijacking.
  /// - Non-destructively hides ad gates (e.g. "We Need Support", "Open 1 ADS per Day") and unblurs background content.
  /// - Pre-seeds daily ad/support storage keys so sites believe user obligations are fulfilled.
  static UserScript getShieldUserScript({HotTeaShieldConfig config = const HotTeaShieldConfig()}) {
    final jsCode = '''
(function() {
  ${config.shieldEnabled && config.defuseAntiAdblockAndGates ? '''
  // --- HotTea Shield Anti-Adblock Defuser & Verification Spoofing ---
  try {
    Object.defineProperty(window, 'canRunAds', { get: () => true, set: () => {}, configurable: true });
    Object.defineProperty(window, 'isAdBlockActive', { get: () => false, set: () => {}, configurable: true });
    Object.defineProperty(window, '__adblocker', { get: () => false, set: () => {}, configurable: true });
  } catch(e) {
    window.canRunAds = true;
    window.isAdBlockActive = false;
    window.__adblocker = false;
  }
  window.adsbygoogle = window.adsbygoogle || [];
  window.adsbygoogle.loaded = true;
  window.adsbygoogle.push = function(args) { return 1; };

  // Mock telemetry & analytics so servers acknowledge completion immediately
  window.gtag = window.gtag || function() {};
  window.ga = window.ga || function() {};
  window.dataLayer = window.dataLayer || [];

  // 1. Storage Pre-seeding (satisfies daily ad, support, and redirection obligations)
  try {
    const today = String(Date.now());
    localStorage.setItem('netmirror_ad_time', today);
    localStorage.setItem('last_ad_time', today);
    localStorage.setItem('support_time', today);
    localStorage.setItem('ad_last_time', today);
    localStorage.setItem('support_ad_time', today);
    localStorage.setItem('daily_ad_viewed', 'true');
    localStorage.setItem('has_supported', 'true');
    localStorage.setItem('ad_completed', 'true');
    localStorage.setItem('ad_shown', 'true');
    localStorage.setItem('ad_view', '1');
    localStorage.setItem('ad_count', '1');
    localStorage.setItem('visited_ad', 'true');
    localStorage.setItem('pop_shown', 'true');
    localStorage.setItem('redirect_done', 'true');
    localStorage.setItem('gate_cleared', 'true');
    sessionStorage.setItem('ad_viewed', 'true');
    sessionStorage.setItem('redirect_done', 'true');
    sessionStorage.setItem('has_supported', 'true');
  } catch(e) {}

  // 2. Defuse ad-network probe checks (fetching /ads.js, /pagead/, or prebid)
  if (window.fetch) {
    try {
      const origFetch = window.fetch.bind(window);
      window.fetch = function(resource, init) {
        try {
          const urlStr = typeof resource === 'string' ? resource : (resource && resource.url ? resource.url : '');
          const u = urlStr.toLowerCase();
          if (u.includes('pagead2.googlesyndication.com') || u.includes('/ads.js') || u.includes('prebid.js') || u.includes('chor-mate')) {
            return Promise.resolve(new Response('window.canRunAds = true;', {
              status: 200,
              statusText: 'OK',
              headers: { 'Content-Type': 'application/javascript' }
            }));
          }
        } catch(e) {}
        return origFetch(resource, init);
      };
    } catch(e) {}
  }

  // 3. Defuse XMLHttpRequest-based adblocker detectors
  if (window.XMLHttpRequest) {
    try {
      const origOpen = XMLHttpRequest.prototype.open;
      const origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.open = function(method, url) {
        this._hotteaProbe = String(url || '').toLowerCase();
        return origOpen.apply(this, arguments);
      };
      XMLHttpRequest.prototype.send = function() {
        if (this._hotteaProbe && (
          this._hotteaProbe.includes('/ads.js') ||
          this._hotteaProbe.includes('pagead2.googlesyndication.com') ||
          this._hotteaProbe.includes('prebid.js') ||
          this._hotteaProbe.includes('adsbygoogle')
        )) {
          try {
            Object.defineProperty(this, 'status', { value: 200, writable: true, configurable: true });
            Object.defineProperty(this, 'readyState', { value: 4, writable: true, configurable: true });
            Object.defineProperty(this, 'responseText', { value: 'window.canRunAds = true;', writable: true, configurable: true });
          } catch(e) {}
          if (typeof this.onreadystatechange === 'function') this.onreadystatechange();
          if (typeof this.onload === 'function') this.onload();
          return;
        }
        return origSend.apply(this, arguments);
      };
    } catch(e) {}
  }

  // 4. Defuse honeypot/bait DOM elements checked by anti-adblock scripts
  try {
    const desc = Object.getOwnPropertyDescriptor(Element.prototype, 'clientHeight') || Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'clientHeight');
    if (desc && desc.get) {
      const origGet = desc.get;
      Object.defineProperty(HTMLElement.prototype, 'clientHeight', {
        get: function() {
          const cls = String(this.className || '').toLowerCase();
          const id = String(this.id || '').toLowerCase();
          if (cls.includes('pub_300') || cls.includes('ad-banner') || cls.includes('adsbox') || id.includes('ad_banner')) {
            return 250;
          }
          return origGet.call(this);
        }
      });
    }
  } catch(e) {}

  if (window.navigator && window.navigator.sendBeacon) {
    const _origSendBeacon = window.navigator.sendBeacon.bind(window.navigator);
    window.navigator.sendBeacon = function(url, data) {
      try {
        const u = String(url).toLowerCase();
        // Allow verification and challenge tokens to reach servers (Turnstile, Cloudflare, hCaptcha, etc.)
        if (u.includes('cdn-cgi/challenge-platform') ||
            u.includes('cloudflare') ||
            u.includes('turnstile') ||
            u.includes('captcha') ||
            !u.startsWith('http')) {
          return _origSendBeacon(url, data);
        }
        // Absorb ad/telemetry beacons
        if (u.includes('google-analytics') ||
            u.includes('doubleclick') ||
            u.includes('telemetry') ||
            u.includes('stats.wp.com')) {
          return true;
        }
        return _origSendBeacon(url, data);
      } catch (e) {
        return true;
      }
    };
  }
  ''' : ''}

  ${config.shieldEnabled && config.keepNavigationsInSameTab ? '''
  // --- Same-Tab Redirection & Popup Neutralizer ---
  // - Neutralizes ad/tracker popups while returning an active mockWindow to satisfy the caller.
  // - Allows legitimate destination navigations to proceed seamlessly in the active tab.
  // - Supports async popup location assignment (e.g. popup.location.href = streamUrl).
  window.open = function(url, target, features) {
    let _locHref = url || '';
    const mockWindow = {
      closed: false,
      focus: function(){},
      blur: function(){},
      close: function(){ this.closed = true; },
      postMessage: function(){},
      addEventListener: function(){},
      removeEventListener: function(){},
      document: { readyState: 'complete', write: function(){}, close: function(){} },
      location: {
        get href() { return _locHref; },
        set href(val) {
          _locHref = val;
          try {
            const p = new URL(val, window.location.href);
            const h = p.hostname.toLowerCase();
            const isAd = /(doubleclick|adsterra|popads|propellerads|exoclick|trafficjunky|adnxs|taboola|outbrain|googleads|syndication|ad-maven|bet365|1xbet|hilltopads|clickadu|popcash|monetag|bidswitch|moatads)/i.test(h);
            if (!isAd) {
              window.location.href = p.href;
            }
          } catch(e) {}
        },
        assign: function(val) { this.href = val; },
        replace: function(val) { this.href = val; },
        toString: function() { return _locHref; }
      }
    };
    if (!url || url === '' || url === 'about:blank') {
      return mockWindow;
    }
    try {
      const parsed = new URL(url, window.location.href);
      const host = parsed.hostname.toLowerCase();
      const isAd = /(doubleclick|adsterra|popads|propellerads|exoclick|trafficjunky|adnxs|taboola|outbrain|googleads|syndication|ad-maven|bet365|1xbet|hilltopads|clickadu|popcash|monetag|bidswitch|moatads)/i.test(host);
      if (isAd) {
        console.log('[HotTea Shield] Prevented ad popup to:', host);
        return mockWindow;
      }
      // Legitimate destination navigation: proceed in current tab so user reaches target content directly
      window.location.href = parsed.href;
      return window;
    } catch(e) {
      return mockWindow;
    }
  };

  // Prevent programmatic hidden anchor clicks intended to open ad popunders
  try {
    if (window.HTMLAnchorElement && window.HTMLAnchorElement.prototype) {
      const _origAnchorClick = window.HTMLAnchorElement.prototype.click;
      window.HTMLAnchorElement.prototype.click = function() {
        try {
          const href = this.href;
          if (href) {
            const parsed = new URL(href, window.location.href);
            const host = parsed.hostname.toLowerCase();
            const isAd = /(doubleclick|adsterra|popads|propellerads|exoclick|trafficjunky|adnxs|taboola|outbrain|googleads|syndication|ad-maven|bet365|1xbet|hilltopads|clickadu|popcash|monetag|bidswitch|moatads)/i.test(host);
            if (isAd) {
              console.log('[HotTea Shield] Prevented simulated ad anchor click to:', host);
              return;
            }
          }
        } catch(e) {}
        return _origAnchorClick.apply(this, arguments);
      };
    }
  } catch(e) {}

  // Prevent annoying onbeforeunload dialog traps
  try {
    Object.defineProperty(window, 'onbeforeunload', {
      get: function() { return null; },
      set: function(_) {}
    });
  } catch(e) {}
  ''' : ''}

  ${config.shieldEnabled && (config.autoDismissCookieWalls || config.defuseAntiAdblockAndGates) ? '''
  // --- Ad-Gates, "We Need Support", & Cookie Wall Neutralizer ---
  function defuseGatesAndOverlays() {
    // 1. Remove blurs on html and body without destroying content layout
    if (document.body) {
      document.body.style.setProperty('filter', 'none', 'important');
      document.body.style.setProperty('-webkit-filter', 'none', 'important');
      if (document.body.style.overflow === 'hidden') {
        document.body.style.setProperty('overflow', 'auto', 'important');
      }
      if (document.body.style.position === 'fixed') {
        document.body.style.setProperty('position', 'static', 'important');
      }
    }
    if (document.documentElement) {
      document.documentElement.style.setProperty('filter', 'none', 'important');
      document.documentElement.style.setProperty('-webkit-filter', 'none', 'important');
      if (document.documentElement.style.overflow === 'hidden') {
        document.documentElement.style.setProperty('overflow', 'auto', 'important');
      }
    }

    // 2. Hide dialogs/modals that specifically contain gate text (never touch verification or root nodes)
    const dialogs = document.querySelectorAll('dialog, [role="dialog"], .modal, .overlay, .popup, #support_modal, #supportModal, .support-gate, .support-modal, #ad-gate, .ad-gate, #daily-ad, .daily-ad, .support-overlay');
    for (let i = 0; i < dialogs.length; i++) {
      const el = dialogs[i];
      if (!el || el === document.body || el === document.documentElement ||
          el.id === 'app' || el.id === 'root' || el.id === 'main' || el.tagName === 'MAIN') {
        continue;
      }
      // Never interfere with Cloudflare Turnstile, reCAPTCHA, or hCaptcha verification challenges
      if (el.id && (el.id.includes('challenge') || el.id.includes('cf-') || el.id.includes('turnstile') || el.id.includes('captcha'))) {
        continue;
      }

      const text = (el.innerText || el.textContent || '').toLowerCase();
      if (text.includes('we need support') ||
          text.includes('open 1 ads per day') ||
          text.includes('open 1 ad per day') ||
          text.includes('check ads more then') ||
          text.includes('check ads more than') ||
          text.includes('after 20 seconds close ads') ||
          text.includes('disable your ad blocker') ||
          text.includes('adblock detected') ||
          text.includes('turn off your adblocker') ||
          text.includes('please disable adblock')) {
        el.style.setProperty('display', 'none', 'important');
        el.style.setProperty('visibility', 'hidden', 'important');
        el.style.setProperty('pointer-events', 'none', 'important');
        el.setAttribute('aria-hidden', 'true');
      }
    }

    // 3. Hide known third-party backdrop/consent overlay elements
    const overlays = document.querySelectorAll('.modal-backdrop, #onetrust-consent-sdk, #onetrust-banner-sdk, .cookie-banner, .cookie-consent, [id*="cookie-notice"], .cmp-container, .fc-consent-root, #sp_message_container, .qc-cmp2-container');
    for (let i = 0; i < overlays.length; i++) {
      const o = overlays[i];
      if (o && o !== document.body && o !== document.documentElement && o.id !== 'app' && o.id !== 'root') {
        o.style.setProperty('display', 'none', 'important');
      }
    }
  }

  // Debounced and re-entrancy safe observer
  let _defuseTimer = null;
  let _observer = null;

  function safeRunDefuse() {
    if (_observer) _observer.disconnect();
    try {
      defuseGatesAndOverlays();
    } catch(e) {}
    if (_observer) {
      const t = document.documentElement || document.body;
      if (t) _observer.observe(t, { childList: true, subtree: true });
    }
  }

  function scheduleDefuse() {
    if (_defuseTimer) return;
    _defuseTimer = setTimeout(function() {
      _defuseTimer = null;
      safeRunDefuse();
    }, 150);
  }

  try {
    _observer = new MutationObserver(scheduleDefuse);
    const target = document.documentElement || document.body;
    if (target) {
      _observer.observe(target, { childList: true, subtree: true });
    } else {
      document.addEventListener('DOMContentLoaded', function() {
        const t = document.documentElement || document.body;
        if (t && _observer) _observer.observe(t, { childList: true, subtree: true });
      });
    }
  } catch(e) {}

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', safeRunDefuse);
  } else {
    safeRunDefuse();
  }
  setTimeout(safeRunDefuse, 300);
  setTimeout(safeRunDefuse, 1000);
  ''' : ''}
})();
''';

    return UserScript(
      source: jsCode,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false,
    );
  }
}
