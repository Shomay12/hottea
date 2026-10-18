# HotTea Installation Guide

This guide covers installing and running HotTea from official sources and building from source for developer previews.

## Current Project Status

HotTea is under active open-source development. 

* **macOS**: Built and tested locally on macOS with native WebKit (`flutter_inappwebview_macos`).
* **iOS**: Built and validated on iOS Simulator (iPhone 17 Pro, iOS 26.1).
* **Web**: Functional preview available; third-party search engines that send `X-Frame-Options: SAMEORIGIN` automatically open in clean browser windows.
* **Android, Windows, Linux**: In active development.

Official pre-built binary packages (DMG, APK, AppImage, EXE) have not yet been published to GitHub Releases. The current recommended method to run HotTea is building from source.

---

## Prerequisites for Building from Source

To build HotTea, ensure the following tooling is installed:

1. **Flutter SDK**: Version 3.38.5 or newer (stable channel)
2. **Dart SDK**: Included with Flutter (3.10+)
3. **Git**: For cloning the repository
4. **Platform Tools**:
   * **macOS**: Xcode 15+ (with Command Line Tools and CocoaPods 1.14+)
   * **iOS**: Xcode 15+ with iOS Simulator
   * **Android**: Android Studio with Android SDK and Build Tools
   * **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`
   * **Windows**: Visual Studio 2022 with "Desktop development with C++"

---

## Step-by-Step Build Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/Shomay12/hottea.git
cd hottea
```

### 2. Verify Your Development Environment

```bash
flutter doctor -v
```

Resolve any missing dependencies identified by `flutter doctor` for your target platform.

### 3. Fetch Dependencies

```bash
flutter pub get
```

### 4. Run Automated Tests

Before launching, verify that all core browser, search, persistence, and UI tests pass:

```bash
flutter test
flutter analyze
```

### 5. Launch HotTea

#### Run on macOS Desktop
```bash
flutter run -d macos
```

#### Run on iOS Simulator
```bash
# Verify available booted simulator
xcrun simctl list devices available | grep Booted

# Run directly
flutter run -d <SIMULATOR_DEVICE_ID>
```

#### Run Web Preview
```bash
flutter run -d chrome
```

---

## Security Verification

When downloading binary releases once published:

* Always verify that files originate from the official repository: `https://github.com/Shomay12/hottea`
* Compare the SHA-256 checksum of your downloaded binary against the published release checksum.
* HotTea binaries will never prompt for administrative privileges during normal web browsing.
