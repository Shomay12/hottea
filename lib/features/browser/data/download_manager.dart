import 'dart:async';
import 'dart:io' as io show File, Directory, Platform, HttpClient;
import 'package:flutter/foundation.dart';
import 'package:hottea/core/utils/external_launcher.dart';
import '../domain/download_item.dart';

/// Central manager for browser downloads in HotTea.
class DownloadManager {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  final ValueNotifier<List<DownloadItem>> downloadsNotifier = ValueNotifier<List<DownloadItem>>([]);
  final Map<String, bool> _cancellationTokens = {};

  List<DownloadItem> get downloads => downloadsNotifier.value;

  /// Handles an automatic download trigger from the WebView.
  Future<void> handleDownloadRequest({
    required Uri url,
    String? suggestedFilename,
    int? contentLength,
    String? mimeType,
  }) async {
    final filename = _sanitizeFilename(suggestedFilename ?? url.pathSegments.lastOrNull ?? 'download');
    await startDownload(url, filename: filename, totalBytes: contentLength ?? -1);
  }

  /// Initiates a file download.
  Future<void> startDownload(Uri url, {required String filename, int totalBytes = -1}) async {
    final id = 'dl_${DateTime.now().millisecondsSinceEpoch}_${downloads.length}';
    final initialItem = DownloadItem(
      id: id,
      url: url,
      filename: filename,
      totalBytes: totalBytes,
      status: DownloadStatus.downloading,
      startedAt: DateTime.now(),
    );

    _updateItem(initialItem);

    if (kIsWeb) {
      // On web, direct download through browser window/anchor
      launchExternalWebUrl(url.toString());
      _updateItem(initialItem.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        completedAt: DateTime.now(),
      ));
      return;
    }

    // Native implementation via dart:io streaming
    _cancellationTokens[id] = false;
    try {
      final destDir = _getDownloadDirectory();
      final targetFile = io.File('${destDir.path}/$filename');
      
      // Prevent accidental overwrites: generate unique name if exists
      final resolvedFile = _resolveUniqueFile(targetFile);

      final client = io.HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode >= 400) {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength > 0 ? response.contentLength : totalBytes;
      final sink = resolvedFile.openWrite();
      int received = 0;

      await for (final chunk in response) {
        if (_cancellationTokens[id] == true) {
          await sink.close();
          try {
            if (await resolvedFile.exists()) await resolvedFile.delete();
          } catch (_) {}
          _updateItem(initialItem.copyWith(
            status: DownloadStatus.cancelled,
            completedAt: DateTime.now(),
          ));
          return;
        }

        sink.add(chunk);
        received += chunk.length;
        final progress = contentLength > 0 ? (received / contentLength).clamp(0.0, 1.0) : 0.0;

        _updateItem(initialItem.copyWith(
          receivedBytes: received,
          totalBytes: contentLength,
          progress: progress,
        ));
      }

      await sink.close();

      _updateItem(initialItem.copyWith(
        receivedBytes: received,
        totalBytes: received,
        progress: 1.0,
        status: DownloadStatus.completed,
        localPath: resolvedFile.path,
        completedAt: DateTime.now(),
      ));
    } catch (e) {
      _updateItem(initialItem.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      ));
    } finally {
      _cancellationTokens.remove(id);
    }
  }

  void cancelDownload(String id) {
    _cancellationTokens[id] = true;
  }

  void clearCompleted() {
    final active = downloads.where((d) => d.status == DownloadStatus.downloading).toList();
    downloadsNotifier.value = active;
  }

  void _updateItem(DownloadItem item) {
    final current = List<DownloadItem>.from(downloadsNotifier.value);
    final index = current.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      current[index] = item;
    } else {
      current.insert(0, item);
    }
    downloadsNotifier.value = current;
  }

  io.Directory _getDownloadDirectory() {
    if (!kIsWeb) {
      if (io.Platform.isIOS) {
        final home = io.Platform.environment['HOME'];
        if (home != null) {
          final docs = io.Directory('$home/Documents/Downloads');
          if (!docs.existsSync()) {
            docs.createSync(recursive: true);
          }
          return docs;
        }
        return io.Directory.systemTemp;
      }
      final home = io.Platform.environment['HOME'] ?? io.Platform.environment['USERPROFILE'];
      if (home != null) {
        final downloads = io.Directory('$home/Downloads');
        if (downloads.existsSync()) return downloads;
      }
      return io.Directory.systemTemp;
    }
    throw UnsupportedError('Filesystem directories unsupported on Web');
  }

  io.File _resolveUniqueFile(io.File original) {
    if (!original.existsSync()) return original;
    final path = original.path;
    final lastDot = path.lastIndexOf('.');
    final base = lastDot != -1 ? path.substring(0, lastDot) : path;
    final ext = lastDot != -1 ? path.substring(lastDot) : '';

    int counter = 1;
    while (true) {
      final candidate = io.File('$base ($counter)$ext');
      if (!candidate.existsSync()) return candidate;
      counter++;
    }
  }

  String _sanitizeFilename(String raw) {
    return raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }
}
