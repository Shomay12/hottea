# HotTea Command-Line Installation Guide

This reference outlines CLI installation instructions for developers and power users.

## Package Manager Status

| Distribution Channel | Target Platform | Current Status | Command |
| :--- | :--- | :--- | :--- |
| **Homebrew Cask** | macOS | Planned (Not yet published) | N/A (Build from source) |
| **AppImage / DEB** | Linux | Planned (Not yet published) | N/A (Build from source) |
| **WinGet / Chocolatey** | Windows | Planned (Not yet published) | N/A (Build from source) |
| **Android ADB** | Android | Supported via local APK | `adb install HotTea.apk` |
| **Git / Flutter CLI** | All Platforms | Fully Supported | See source instructions below |

*Notice: We do not invent Homebrew formulas or WinGet identifiers before they are published and accepted into upstream package registries.*

---

## macOS CLI Source Build

1. Ensure Xcode and CocoaPods are installed:
   ```bash
   xcode-select -p
   pod --version
   ```

2. Clone and build the macOS debug or release application:
   ```bash
   git clone https://github.com/Shomay12/hottea.git
   cd hottea
   flutter pub get
   flutter build macos --debug
   ```

3. Launch the compiled application:
   ```bash
   open build/macos/Build/Products/Debug/hottea.app
   ```

---

## iOS Simulator CLI Installation

1. List available simulators and boot your preferred device:
   ```bash
   xcrun simctl list devices available
   xcrun simctl boot "iPhone 17 Pro"
   ```

2. Build the simulator app bundle:
   ```bash
   flutter build ios --simulator
   ```

3. Install and launch the application on the booted simulator:
   ```bash
   xcrun simctl install booted build/ios/iphonesimulator/Runner.app
   xcrun simctl launch booted org.hottea.hottea
   ```

---

## Android ADB Installation (When APK is Available)

1. Verify your device is connected over USB or wireless debugging:
   ```bash
   adb devices
   ```

2. Install the APK to the connected device:
   ```bash
   adb install -r HotTea.apk
   ```

3. Launch the application:
   ```bash
   adb shell monkey -p org.hottea.hottea -c android.intent.category.LAUNCHER 1
   ```

---

## Linux CLI Source Build

1. Install system development dependencies on Debian/Ubuntu:
   ```bash
   sudo apt-get update
   sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
   ```

2. Fetch dependencies and compile:
   ```bash
   git clone https://github.com/Shomay12/hottea.git
   cd hottea
   flutter pub get
   flutter build linux
   ```

3. Execute the binary:
   ```bash
   ./build/linux/x64/release/bundle/hottea
   ```
