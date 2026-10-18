enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  cancelled,
}

/// Represents a single file download in HotTea.
class DownloadItem {
  final String id;
  final Uri url;
  final String filename;
  final int receivedBytes;
  final int totalBytes;
  final double progress;
  final DownloadStatus status;
  final String? localPath;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;

  const DownloadItem({
    required this.id,
    required this.url,
    required this.filename,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.localPath,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
  });

  DownloadItem copyWith({
    String? id,
    Uri? url,
    String? filename,
    int? receivedBytes,
    int? totalBytes,
    double? progress,
    DownloadStatus? status,
    String? localPath,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get formattedSize {
    if (totalBytes <= 0) {
      if (receivedBytes > 0) {
        return '${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return 'Unknown size';
    }
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final recMb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$recMb / $totalMb MB';
  }
}
