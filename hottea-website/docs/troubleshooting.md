# HotTea Troubleshooting Guide

This guide provides verified solutions to common development, runtime, and build issues in HotTea.

---

## 1. macOS Build / App Launch Issues

### `sandbox_extension_issue_file failed for : 2 (No such file or directory)`
* **Cause**: On macOS, sandboxed applications require explicit entitlement access to user-selected files or standard download directories.
* **Solution**: In `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`, verify `com.apple.security.files.user-selected.read-write` and `com.apple.security.files.downloads.read-write` are declared `true`.

### Xcode 27 / macOS 27 Multi-Architecture `lipo` Error
* **Symptom**: `Target debug_unpack_ios failed: Binary ... does not contain architectures "arm64 x86_64"`
* **Cause**: Apple's modern `lipo -verify_arch` utility expects exactly one architecture argument for simulator targets.
* **Solution**: In `ios/Flutter/Debug.xcconfig` and `ios/Flutter/Release.xcconfig`, ensure:
  ```xcconfig
  ARCHS[sdk=iphonesimulator*] = arm64
  ONLY_ACTIVE_ARCH = YES
  ```

---

## 2. Web Preview Issues

### Search Providers Fail to Load in iframe (`X-Frame-Options` or `CSP`)
* **Symptom**: Google, DuckDuckGo, Bing, or Brave display a blank gray screen or refused-to-connect error when browsing in the Flutter Web build.
* **Explanation**: Major search providers send `X-Frame-Options: SAMEORIGIN` or restrictive `Content-Security-Policy: frame-ancestors` HTTP response headers. Browsers intentionally prohibit embedding these sites inside standard iframes.
* **HotTea Resolution**: HotTea detects web fallback mode and automatically opens external search providers in an isolated browser window with a transparent explanation banner. On native desktop (macOS) and mobile (iOS), HotTea uses native WebKit instances where `X-Frame-Options` restrictions do not apply to top-level WebKit frames.

---

## 3. Persistence & SQLite Issues

### `*** sqflite warning *** You are changing sqflite default factory`
* **Status**: Benign diagnostic message.
* **Explanation**: On desktop platforms (macOS, Linux, Windows), `sqflite_common_ffi` overrides the platform factory with native SQLite C bindings. On Web, `sqflite_common_ffi_web` initializes IndexedDB/Wasm SQLite bindings. This warning confirms the appropriate platform database driver is engaged.

---

## 4. Reporting New Issues

If you encounter an issue not covered above:

1. Search existing issues: `https://github.com/Shomay12/hottea/issues`
2. Include your operating system version, Flutter version (`flutter --version`), and reproduction steps.
3. For security vulnerabilities, review our responsible disclosure guidelines in `contributing.md`.
