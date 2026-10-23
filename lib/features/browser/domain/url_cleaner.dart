/// Brave-grade QueryFilter and De-AMP URL Cleaner for HotTea.
///
/// Strips invasive tracking, marketing, and affiliate telemetry tokens from URLs
/// and unwraps Google AMP caches directly to publisher canonical URLs.
class UrlCleaner {
  UrlCleaner._();

  /// Known tracking query parameter keys commonly stripped by Brave Shields.
  static const Set<String> trackingParameters = {
    // Google / Analytics
    'utm_source',
    'utm_medium',
    'utm_campaign',
    'utm_term',
    'utm_content',
    'utm_id',
    'utm_source_platform',
    'utm_creative',
    'gclid',
    'gclsrc',
    'dclid',
    'gad_source',
    'gbraid',
    'wbraid',

    // Facebook / Instagram / Meta
    'fbclid',
    'fbc',
    'fbp',
    'igshid',

    // Twitter / X
    'twclid',
    'tw_source',

    // Microsoft / Bing
    'msclkid',

    // Mailchimp / Email Marketing
    'mc_eid',
    'mc_cid',

    // HubSpot
    '_hsenc',
    '_hsmi',
    'hsa_cam',
    'hsa_grp',
    'hsa_mt',
    'hsa_src',
    'hsa_ad',
    'hsa_acc',
    'hsa_net',
    'hsa_kw',
    'hsa_tgt',
    'hsa_ver',

    // Yandex
    'yclid',
    'ym_debug',

    // TikTok
    'ttclid',

    // Pinterest
    'epik',

    // General Tracking & Affiliates
    'mkt_tok',
    '_openstat',
    'wickedid',
    'otc',
    'vero_id',
    'zanpid',
    'ref_src',
    'ref_url',
    'action_object_map',
    'action_type_map',
    'action_ref_map',
  };

  /// Unwraps Google AMP and CDN AMP cache URLs to canonical publisher URLs.
  static Uri deAmp(Uri uri) {
    final host = uri.host.toLowerCase();

    // 1. Google AMP Proxy: google.com/amp/s/example.com/path or google.com/amp/example.com/path
    if (host.contains('google.') && uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'amp') {
      final segments = uri.pathSegments;
      if (segments.length >= 3 && segments[1] == 's') {
        final targetHost = segments[2];
        final remainingPath = segments.sublist(3).join('/');
        final query = uri.hasQuery ? '?${uri.query}' : '';
        final unwrapped = 'https://$targetHost${remainingPath.isNotEmpty ? '/$remainingPath' : ''}$query';
        return Uri.tryParse(unwrapped) ?? uri;
      } else if (segments.length >= 2) {
        final targetHost = segments[1];
        final remainingPath = segments.sublist(2).join('/');
        final query = uri.hasQuery ? '?${uri.query}' : '';
        final unwrapped = 'https://$targetHost${remainingPath.isNotEmpty ? '/$remainingPath' : ''}$query';
        return Uri.tryParse(unwrapped) ?? uri;
      }
    }

    // 2. AMP Project CDN: *.cdn.ampproject.org/c/s/example.com/...
    if (host.endsWith('.ampproject.org') && uri.pathSegments.contains('s')) {
      final sIndex = uri.pathSegments.indexOf('s');
      if (sIndex + 1 < uri.pathSegments.length) {
        final targetHost = uri.pathSegments[sIndex + 1];
        final remainingPath = uri.pathSegments.sublist(sIndex + 2).join('/');
        final query = uri.hasQuery ? '?${uri.query}' : '';
        final unwrapped = 'https://$targetHost${remainingPath.isNotEmpty ? '/$remainingPath' : ''}$query';
        return Uri.tryParse(unwrapped) ?? uri;
      }
    }

    return uri;
  }

  /// Removes tracking parameters from [uri].
  static Uri stripTrackingParameters(Uri uri) {
    if (!uri.hasQuery) return uri;

    final queryParams = Map<String, String>.from(uri.queryParameters);
    var modified = false;

    final keysToRemove = <String>[];
    for (final key in queryParams.keys) {
      final lowerKey = key.toLowerCase();
      if (trackingParameters.contains(lowerKey) ||
          lowerKey.startsWith('utm_') ||
          lowerKey.startsWith('hsa_')) {
        keysToRemove.add(key);
        modified = true;
      }
    }

    if (!modified) return uri;

    for (final k in keysToRemove) {
      queryParams.remove(k);
    }

    return uri.replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  /// Performs full Brave-grade sanitization: De-AMP + Tracking Parameter Stripping.
  static Uri clean(Uri uri, {bool deAmpEnabled = true, bool stripTrackers = true}) {
    var cleaned = uri;
    if (deAmpEnabled) {
      cleaned = deAmp(cleaned);
    }
    if (stripTrackers) {
      cleaned = stripTrackingParameters(cleaned);
    }
    return cleaned;
  }
}
