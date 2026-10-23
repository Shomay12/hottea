/// Real-time and cumulative statistics for HotTea Shield protections.
/// Modeled after Brave Shields metrics.
class ShieldStats {
  /// Trackers, ads, and popups blocked on the active page.
  final int trackersBlockedOnPage;

  /// Cumulative lifetime trackers & ads blocked across all browsing sessions.
  final int totalTrackersBlocked;

  /// Estimated data saved in bytes (~50 KB per blocked ad/tracker request).
  int get estimatedBandwidthSavedBytes => totalTrackersBlocked * 51200;

  /// Estimated loading time saved in milliseconds (~50 ms latency savings per blocked request).
  int get estimatedTimeSavedMs => totalTrackersBlocked * 50;

  const ShieldStats({
    this.trackersBlockedOnPage = 0,
    this.totalTrackersBlocked = 0,
  });

  ShieldStats copyWith({
    int? trackersBlockedOnPage,
    int? totalTrackersBlocked,
  }) {
    return ShieldStats(
      trackersBlockedOnPage: trackersBlockedOnPage ?? this.trackersBlockedOnPage,
      totalTrackersBlocked: totalTrackersBlocked ?? this.totalTrackersBlocked,
    );
  }

  String get formattedBandwidthSaved {
    final bytes = estimatedBandwidthSavedBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedTimeSaved {
    final ms = estimatedTimeSavedMs;
    if (ms < 1000) return '${ms}ms';
    if (ms < 60000) return '${(ms / 1000).toStringAsFixed(1)}s';
    return '${(ms / 60000).toStringAsFixed(1)}m';
  }
}
