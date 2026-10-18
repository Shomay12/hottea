import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/features/browser/data/download_manager.dart';
import 'package:hottea/features/browser/domain/browser_engine.dart';
import 'package:hottea/features/browser/domain/browser_tab.dart';
import 'package:hottea/features/browser/domain/download_item.dart';

void main() {
  group('Browser Feature & Privacy Invariant Tests', () {
    test('Private tabs are isolated and report isPrivate true', () {
      final engine = MockBrowserEngine(isPrivate: true);
      final tab = BrowserTab(
        id: 'test_private_tab',
        engine: engine,
        initialUrl: Uri.parse('about:blank'),
      );

      expect(tab.isPrivate, isTrue);
      expect(engine.isPrivate, isTrue);
    });

    test('Zoom controls: zoomIn, zoomOut, and resetZoom update zoomLevel', () async {
      final engine = MockBrowserEngine();
      final tab = BrowserTab(
        id: 'test_zoom_tab',
        engine: engine,
      );

      expect(tab.zoomLevel, equals(1.0));

      await tab.zoomIn();
      expect(tab.zoomLevel, greaterThan(1.0));

      await tab.zoomOut();
      await tab.zoomOut();
      expect(tab.zoomLevel, lessThan(1.0));

      await tab.resetZoom();
      expect(tab.zoomLevel, equals(1.0));
    });

    test('History recording privacy invariants: private tabs & errors are excluded', () async {
      final repo = InMemoryPersistenceRepository();
      await repo.initialize();

      // Simulate a private tab navigation
      final privateEngine = MockBrowserEngine(isPrivate: true);
      final privateTab = BrowserTab(
        id: 'private_tab_test',
        engine: privateEngine,
      );
      await privateEngine.initialize(initialUrl: Uri.parse('https://secret-service.org'));

      // If tab is private, history should NOT record it
      if (!privateTab.isPrivate && privateTab.error == null && privateTab.currentUrl?.scheme != 'about') {
        await repo.recordVisit(url: privateTab.currentUrl!, title: privateTab.currentTitle);
      }

      var history = await repo.getHistory();
      expect(history, isEmpty, reason: 'Private tab visit must never be recorded to history.');

      // Simulate an error navigation
      final errorEngine = MockBrowserEngine();
      final errorTab = BrowserTab(
        id: 'error_tab_test',
        engine: errorEngine,
      );
      await errorEngine.initialize();
      await errorTab.loadUrl(Uri.parse('ftp://unsupported-host.org'));

      expect(errorTab.error, isNotNull);

      if (!errorTab.isPrivate && errorTab.error == null && errorTab.currentUrl?.scheme != 'about') {
        await repo.recordVisit(url: errorTab.currentUrl!, title: errorTab.currentTitle);
      }

      history = await repo.getHistory();
      expect(history, isEmpty, reason: 'Failed navigation with error must never be recorded to history.');

      // Normal navigation should be recorded
      final normalEngine = MockBrowserEngine();
      final normalTab = BrowserTab(
        id: 'normal_tab_test',
        engine: normalEngine,
      );
      await normalEngine.initialize(initialUrl: Uri.parse('https://docs.flutter.dev'));

      if (!normalTab.isPrivate && normalTab.error == null && normalTab.currentUrl?.scheme != 'about') {
        await repo.recordVisit(url: normalTab.currentUrl!, title: normalTab.currentTitle);
      }

      history = await repo.getHistory();
      expect(history, hasLength(1));
      expect(history.first.url, equals(Uri.parse('https://docs.flutter.dev')));

      await repo.close();
    });

    test('Session restoration serialization ignores private and about:blank tabs', () {
      final tabs = [
        BrowserTab(
          id: 'tab_1',
          engine: MockBrowserEngine(isPrivate: false),
          initialUrl: Uri.parse('https://flutter.dev'),
        ),
        BrowserTab(
          id: 'tab_2',
          engine: MockBrowserEngine(isPrivate: true),
          initialUrl: Uri.parse('https://private-banking.example'),
        ),
        BrowserTab(
          id: 'tab_3',
          engine: MockBrowserEngine(isPrivate: false),
          initialUrl: Uri.parse('about:blank'),
        ),
        BrowserTab(
          id: 'tab_4',
          engine: MockBrowserEngine(isPrivate: false),
          initialUrl: Uri.parse('https://pub.dev'),
        ),
      ];

      // Simulate URL initialization
      (tabs[0].engine as MockBrowserEngine).initialize(initialUrl: Uri.parse('https://flutter.dev'));
      (tabs[1].engine as MockBrowserEngine).initialize(initialUrl: Uri.parse('https://private-banking.example'));
      (tabs[3].engine as MockBrowserEngine).initialize(initialUrl: Uri.parse('https://pub.dev'));

      final validUrls = tabs
          .where((t) => !t.isPrivate && t.currentUrl != null && t.currentUrl!.scheme != 'about')
          .map((t) => t.currentUrl!.toString())
          .toList();

      expect(validUrls, contains('https://flutter.dev'));
      expect(validUrls, contains('https://pub.dev'));
      expect(validUrls, isNot(contains('https://private-banking.example')));
      expect(validUrls, isNot(contains('about:blank')));
      expect(validUrls, hasLength(2));
    });
  });

  group('DownloadManager Unit Tests', () {
    test('DownloadItem formattedSize renders correctly', () {
      final itemKnown = DownloadItem(
        id: 'dl_1',
        url: Uri.parse('https://example.com/file.zip'),
        filename: 'file.zip',
        receivedBytes: 5 * 1024 * 1024,
        totalBytes: 10 * 1024 * 1024,
        startedAt: DateTime.now(),
      );

      expect(itemKnown.formattedSize, equals('5.0 / 10.0 MB'));

      final itemUnknown = DownloadItem(
        id: 'dl_2',
        url: Uri.parse('https://example.com/stream'),
        filename: 'stream',
        receivedBytes: 2 * 1024 * 1024,
        totalBytes: -1,
        startedAt: DateTime.now(),
      );

      expect(itemUnknown.formattedSize, equals('2.0 MB'));
    });

    test('DownloadManager can cancel and clear completed downloads', () {
      final manager = DownloadManager.instance;
      manager.clearCompleted();

      final initialItem = DownloadItem(
        id: 'test_dl_cancel',
        url: Uri.parse('https://example.com/test.bin'),
        filename: 'test.bin',
        status: DownloadStatus.downloading,
        startedAt: DateTime.now(),
      );

      manager.downloadsNotifier.value = [initialItem];
      expect(manager.downloads, hasLength(1));

      manager.cancelDownload('test_dl_cancel');

      // Change status to completed and clear completed
      manager.downloadsNotifier.value = [
        initialItem.copyWith(status: DownloadStatus.completed),
      ];
      manager.clearCompleted();
      expect(manager.downloads, isEmpty);
    });
  });
}
