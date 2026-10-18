import 'package:flutter/widgets.dart';
import '../domain/browser_engine.dart';
import 'inapp_browser_engine.dart';

/// Factory for creating platform-appropriate [BrowserEngine] instances.
class BrowserEngineFactory {
  BrowserEngineFactory._();

  /// Creates a [BrowserEngine] instance.
  ///
  /// In automated test environments (e.g. `flutter test`) or when [forceMock] is true,
  /// returns a [MockBrowserEngine] to prevent platform-channel timeouts.
  /// On runtime platforms (Web, macOS, iOS, Android, Windows), returns [InAppBrowserEngine].
  static BrowserEngine createEngine({
    Uri? initialUrl,
    bool forceMock = false,
    bool isPrivate = false,
  }) {
    if (forceMock || _isTestEnvironment()) {
      final engine = MockBrowserEngine(isPrivate: isPrivate);
      engine.initialize(initialUrl: initialUrl);
      return engine;
    }

    final engine = InAppBrowserEngine(initialUrl: initialUrl, isPrivate: isPrivate);
    engine.initialize(initialUrl: initialUrl);
    return engine;
  }

  static bool _isTestEnvironment() {
    return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');
  }
}
