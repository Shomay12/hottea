import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Configuration settings for HotTea Shield privacy, protection, and redirection engine.
/// Elevated with Brave-grade privacy protections (QueryFilter, De-AMP, Farbling, Per-Site Shields).
class HotTeaShieldConfig {
  final bool shieldEnabled;
  final bool blockAdsAndTrackers;
  final bool blockThirdPartyCookies;
  final bool keepNavigationsInSameTab;
  final bool defuseAntiAdblockAndGates;
  final bool autoDismissCookieWalls;

  // Brave-Grade Extended Protections:
  final bool cleanUrls;
  final bool deAmpEnabled;
  final bool blockFingerprinting;
  final bool blockScripts;
  final bool aggressiveAdBlocking;
  final Set<String> disabledDomains;

  const HotTeaShieldConfig({
    this.shieldEnabled = true,
    this.blockAdsAndTrackers = true,
    this.blockThirdPartyCookies = true,
    this.keepNavigationsInSameTab = true,
    this.defuseAntiAdblockAndGates = true,
    this.autoDismissCookieWalls = true,
    this.cleanUrls = true,
    this.deAmpEnabled = true,
    this.blockFingerprinting = true,
    this.blockScripts = false,
    this.aggressiveAdBlocking = false,
    this.disabledDomains = const {},
  });

  /// Checks whether shield protection is active for a given host or URL.
  bool isShieldEnabledForHost(String? host) {
    if (!shieldEnabled) return false;
    if (host == null || host.isEmpty) return true;
    final lower = host.toLowerCase();
    for (final domain in disabledDomains) {
      if (lower == domain || lower.endsWith('.$domain')) {
        return false;
      }
    }
    return true;
  }

  HotTeaShieldConfig copyWith({
    bool? shieldEnabled,
    bool? blockAdsAndTrackers,
    bool? blockThirdPartyCookies,
    bool? keepNavigationsInSameTab,
    bool? defuseAntiAdblockAndGates,
    bool? autoDismissCookieWalls,
    bool? cleanUrls,
    bool? deAmpEnabled,
    bool? blockFingerprinting,
    bool? blockScripts,
    bool? aggressiveAdBlocking,
    Set<String>? disabledDomains,
  }) {
    return HotTeaShieldConfig(
      shieldEnabled: shieldEnabled ?? this.shieldEnabled,
      blockAdsAndTrackers: blockAdsAndTrackers ?? this.blockAdsAndTrackers,
      blockThirdPartyCookies: blockThirdPartyCookies ?? this.blockThirdPartyCookies,
      keepNavigationsInSameTab: keepNavigationsInSameTab ?? this.keepNavigationsInSameTab,
      defuseAntiAdblockAndGates: defuseAntiAdblockAndGates ?? this.defuseAntiAdblockAndGates,
      autoDismissCookieWalls: autoDismissCookieWalls ?? this.autoDismissCookieWalls,
      cleanUrls: cleanUrls ?? this.cleanUrls,
      deAmpEnabled: deAmpEnabled ?? this.deAmpEnabled,
      blockFingerprinting: blockFingerprinting ?? this.blockFingerprinting,
      blockScripts: blockScripts ?? this.blockScripts,
      aggressiveAdBlocking: aggressiveAdBlocking ?? this.aggressiveAdBlocking,
      disabledDomains: disabledDomains ?? this.disabledDomains,
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
      'clean_urls': cleanUrls.toString(),
      'deamp_enabled': deAmpEnabled.toString(),
      'block_fingerprinting': blockFingerprinting.toString(),
      'block_scripts': blockScripts.toString(),
      'aggressive_ad_blocking': aggressiveAdBlocking.toString(),
      'disabled_domains': disabledDomains.join(','),
    };
  }

  factory HotTeaShieldConfig.fromPersistenceMap(Map<String, String?> map) {
    final disabledStr = map['disabled_domains'] ?? '';
    final disabled = disabledStr.isEmpty
        ? <String>{}
        : disabledStr.split(',').map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();

    return HotTeaShieldConfig(
      shieldEnabled: map['shield_enabled'] != 'false',
      blockAdsAndTrackers: map['block_ads_trackers'] != 'false',
      blockThirdPartyCookies: map['block_third_party_cookies'] != 'false',
      keepNavigationsInSameTab: map['same_tab_redirection'] != 'false',
      defuseAntiAdblockAndGates: map['defuse_anti_adblock'] != 'false',
      autoDismissCookieWalls: map['auto_dismiss_cookie_walls'] != 'false',
      cleanUrls: map['clean_urls'] != 'false',
      deAmpEnabled: map['deamp_enabled'] != 'false',
      blockFingerprinting: map['block_fingerprinting'] != 'false',
      blockScripts: map['block_scripts'] == 'true',
      aggressiveAdBlocking: map['aggressive_ad_blocking'] == 'true',
      disabledDomains: disabled,
    );
  }
}

/// Rules, filters, scripts, and farbling engine powering HotTea Shield.
///
/// Ensures:
/// 1. Ad and tracker blocking without breaking website functional logic.
/// 2. Third-party cookie blocking while preserving first-party authentication/session cookies.
/// 3. Same-tab redirection lock: Links and redirects stay in the active tab without getting lost.
/// 4. Anti-adblock and fake redirection gate defusal: Servers believe tracking/redirection
///    acknowledged so content renders openly without friction or delay.
/// 5. Brave-grade Browser Fingerprinting Protection (Canvas, Audio, WebGL, Screen Farbling).
/// 6. Clean URLs & De-AMP canonical redirection.
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
    // Expanded telemetry and tracker domains
    'amplitude.com',
    'mixpanel.com',
    'segment.io',
    'segment.com',
    'coinhive.com',
    'coin-hive.com',
    'adroll.com',
    'serving-sys.com',
    'smartadserver.com',
    'yieldmo.com',
    'sharethrough.com',
    'inmobi.com',
    'applovin.com',
    'ironsrc.com',
    'mouseflow.com',
    'crazyegg.com',
    'fullstory.com',
  ];

  /// Combined regex matching ad and tracker network requests.
  static final RegExp adRegex = RegExp(
    r'(doubleclick\.net|googlesyndication\.com|google-analytics\.com|adservice\.google\.com|pagead2\.googlesyndication\.com|criteo\.com|criteo\.net|adnxs\.com|amazon-adsystem\.com|taboola\.com|outbrain\.com|popads\.net|propellerads\.com|adsterra\.com|exoclick\.com|ad-maven\.com|trafficjunky|monetag\.com|bidswitch\.net|moatads\.com|scorecardresearch\.com|hotjar\.com|clarity\.ms|fbevents\.js|rubiconproject\.com|pubmatic\.com|openx\.net|hilltopads|clickadu|popcash|amplitude\.com|mixpanel\.com|segment\.io|segment\.com|coinhive\.com|adroll\.com|smartadserver\.com|yieldmo\.com|sharethrough\.com|inmobi\.com|applovin\.com)',
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
      final cosmeticSelector = config.aggressiveAdBlocking
          ? '.ad-banner, .advertisement, [id*="ad_banner"], [id*="google_ads"], [class*="sponsored-post"], ins.adsbygoogle, .taboola-ad, .outbrain-ad, #support_modal, #supportModal, .support-gate, .support-modal, #ad-gate, .ad-gate, #daily-ad, .daily-ad, #support-modal, .support-overlay, [class*="ad-slot"], [id*="ad-slot"], [data-ad-unit], [data-ad-slot], [class*="sponsored"], [id*="sponsored"], .ytp-ad-overlay-container, .ytp-ad-message-container, .video-ads, .ad-showing'
          : '.ad-banner, .advertisement, [id*="ad_banner"], [id*="google_ads"], [class*="sponsored-post"], ins.adsbygoogle, .taboola-ad, .outbrain-ad, #support_modal, #supportModal, .support-gate, .support-modal, #ad-gate, .ad-gate, #daily-ad, .daily-ad, #support-modal, .support-overlay';

      blockers.add(
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: '.*',
          ),
          action: ContentBlockerAction(
            type: ContentBlockerActionType.CSS_DISPLAY_NONE,
            selector: cosmeticSelector,
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
            selector: '#onetrust-consent-sdk, #onetrust-banner-sdk, .cookie-banner, .cookie-consent, [id*="cookie-notice"], .cmp-container, .fc-consent-root, #sp_message_container, .qc-cmp2-container, #didomi-host',
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
  /// - Brave Farbling Defenses: Randomizes Canvas, WebGL, AudioContext, and Hardware fingerprint vectors.
  /// - Real-time Shield Block Counter Bridge.
  static UserScript getShieldUserScript({HotTeaShieldConfig config = const HotTeaShieldConfig()}) {
    final jsCode = '''
(function() {
  // --- HotTea Shield Real-time Block Counter Bridge ---
  window.__hotteaBlockedCount = 0;
  function reportBlockedItem(delta) {
    window.__hotteaBlockedCount += (delta || 1);
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onShieldBlockedItem', window.__hotteaBlockedCount);
      }
    } catch(e) {}
  }

  ${config.shieldEnabled && config.blockFingerprinting ? '''
  // --- Brave-Grade Fingerprinting Defenses (Farbling) ---
  // 1. Canvas Farbling (Subtly randomizes 1-bit pixel noise to prevent canvas hash fingerprinting)
  try {
    if (window.HTMLCanvasElement && window.HTMLCanvasElement.prototype) {
      const origToDataURL = HTMLCanvasElement.prototype.toDataURL;
      HTMLCanvasElement.prototype.toDataURL = function() {
        try {
          const ctx = this.getContext('2d');
          if (ctx) {
            const imgData = ctx.getImageData(0, 0, Math.min(this.width, 16), Math.min(this.height, 16));
            if (imgData && imgData.data && imgData.data.length > 0) {
              imgData.data[0] = (imgData.data[0] ^ 1) & 0xFF;
              ctx.putImageData(imgData, 0, 0);
            }
          }
        } catch(e) {}
        return origToDataURL.apply(this, arguments);
      };
    }
    if (window.CanvasRenderingContext2D && window.CanvasRenderingContext2D.prototype) {
      const origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
      CanvasRenderingContext2D.prototype.getImageData = function(sx, sy, sw, sh) {
        const res = origGetImageData.apply(this, arguments);
        try {
          if (res && res.data && res.data.length > 0) {
            res.data[0] = (res.data[0] ^ 1) & 0xFF;
          }
        } catch(e) {}
        return res;
      };
    }
  } catch(e) {}

  // 2. WebGL Farbling (Masks GPU vendor & renderer strings)
  try {
    const spoofWebGL = function(proto) {
      if (!proto || !proto.getParameter) return;
      const origGetParameter = proto.getParameter;
      proto.getParameter = function(param) {
        // 0x9245: UNMASKED_VENDOR_WEBGL, 0x9246: UNMASKED_RENDERER_WEBGL
        if (param === 0x9245) return 'HotTea / Brave Privacy Shield GPU';
        if (param === 0x9246) return 'HotTea Angle High-Fidelity Renderer';
        return origGetParameter.apply(this, arguments);
      };
    };
    if (window.WebGLRenderingContext) spoofWebGL(WebGLRenderingContext.prototype);
    if (window.WebGL2RenderingContext) spoofWebGL(WebGL2RenderingContext.prototype);
  } catch(e) {}

  // 3. AudioContext Farbling
  try {
    if (window.AnalyserNode && window.AnalyserNode.prototype.getFloatFrequencyData) {
      const origFloatFreq = window.AnalyserNode.prototype.getFloatFrequencyData;
      window.AnalyserNode.prototype.getFloatFrequencyData = function(arr) {
        origFloatFreq.apply(this, arguments);
        for (let i = 0; i < Math.min(arr.length, 10); i++) {
          arr[i] += (Math.random() - 0.5) * 0.0001;
        }
      };
    }
  } catch(e) {}

  // 4. Hardware & Battery Shielding
  try {
    Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => 4, configurable: true });
    Object.defineProperty(navigator, 'deviceMemory', { get: () => 8, configurable: true });
    if (navigator.getBattery) {
      navigator.getBattery = function() { return Promise.reject(new Error('Battery API restricted by HotTea Shield')); };
    }
  } catch(e) {}
  ''' : ''}

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
            reportBlockedItem(1);
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
          reportBlockedItem(1);
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
        if (u.includes('cdn-cgi/challenge-platform') ||
            u.includes('cloudflare') ||
            u.includes('turnstile') ||
            u.includes('captcha') ||
            !u.startsWith('http')) {
          return _origSendBeacon(url, data);
        }
        if (u.includes('google-analytics') ||
            u.includes('doubleclick') ||
            u.includes('telemetry') ||
            u.includes('stats.wp.com')) {
          reportBlockedItem(1);
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
            } else {
              reportBlockedItem(1);
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
        reportBlockedItem(1);
        console.log('[HotTea Shield] Prevented ad popup to:', host);
        return mockWindow;
      }
      window.location.href = parsed.href;
      return window;
    } catch(e) {
      return mockWindow;
    }
  };

  try {
    if (window.HTMLAnchorElement && window.HTMLAnchorElement.prototype) {
      const _origAnchorClick = window.HTMLAnchorElement.prototype.click;
      window.HTMLAnchorElement.prototype.click = function() {
        try {
          final href = this.href;
          if (href) {
            const parsed = new URL(href, window.location.href);
            const host = parsed.hostname.toLowerCase();
            const isAd = /(doubleclick|adsterra|popads|propellerads|exoclick|trafficjunky|adnxs|taboola|outbrain|googleads|syndication|ad-maven|bet365|1xbet|hilltopads|clickadu|popcash|monetag|bidswitch|moatads)/i.test(host);
            if (isAd) {
              reportBlockedItem(1);
              console.log('[HotTea Shield] Prevented simulated ad anchor click to:', host);
              return;
            }
          }
        } catch(e) {}
        return _origAnchorClick.apply(this, arguments);
      };
    }
  } catch(e) {}

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

    const dialogs = document.querySelectorAll('dialog, [role="dialog"], .modal, .overlay, .popup, #support_modal, #supportModal, .support-gate, .support-modal, #ad-gate, .ad-gate, #daily-ad, .daily-ad, .support-overlay');
    for (let i = 0; i < dialogs.length; i++) {
      const el = dialogs[i];
      if (!el || el === document.body || el === document.documentElement ||
          el.id === 'app' || el.id === 'root' || el.id === 'main' || el.tagName === 'MAIN') {
        continue;
      }
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
        reportBlockedItem(1);
      }
    }

    const overlays = document.querySelectorAll('.modal-backdrop, #onetrust-consent-sdk, #onetrust-banner-sdk, .cookie-banner, .cookie-consent, [id*="cookie-notice"], .cmp-container, .fc-consent-root, #sp_message_container, .qc-cmp2-container');
    for (let i = 0; i < overlays.length; i++) {
      const o = overlays[i];
      if (o && o !== document.body && o !== document.documentElement && o.id !== 'app' && o.id !== 'root') {
        o.style.setProperty('display', 'none', 'important');
        reportBlockedItem(1);
      }
    }
  }

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
