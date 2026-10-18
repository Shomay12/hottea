# Platform Browser-Engine Integration Analysis

This document evaluates the browser-engine options across the five target platforms for **HotTea**: Windows, Linux, macOS, Android, and iOS.

---

## 1. Executive Summary

| Platform | Recommended Engine / Adapter | Underlying Native Runtime | Package License | Engine License | Feasibility & Stability |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **macOS** | `flutter_inappwebview` or `webview_flutter_wkwebview` | Apple WebKit (`WKWebView`) | Apache-2.0 / BSD-3-Clause | Apple Proprietary / WebKit Open Source | High. Native inline view via AppKit. |
| **iOS** | `flutter_inappwebview` or `webview_flutter_wkwebview` | Apple WebKit (`WKWebView`) | Apache-2.0 / BSD-3-Clause | Apple Proprietary (App Store mandated) | High. Mature and standard. |
| **Android** | `flutter_inappwebview` or `webview_flutter_android` | Android System WebView (Chromium) | Apache-2.0 / BSD-3-Clause | BSD-3-Clause / Chromium | High. Native inline view via SurfaceView/Texture. |
| **Windows** | `flutter_inappwebview_windows` or `webview_windows` | Microsoft Edge WebView2 (Chromium) | Apache-2.0 / MIT | Microsoft Evergreen Runtime (free redistribution) | High. Lightweight; preinstalled on Windows 10/11. |
| **Linux** | Custom WebKitGTK platform plugin or `webview_cef` | WebKitGTK (epiphany stack) or CEF (Chromium) | LGPL / BSD-3-Clause | LGPL-2.1 / BSD-3-Clause | Medium to Complex. Requires specialized handling. |

> **Critical Note on Multi-Platform Reality:**  
> There is **no single off-the-shelf Flutter package** that provides clean, unified, in-tree rendering across all 5 platforms simultaneously out-of-the-box. Linux desktop is the key divergence point. Therefore, the shared HotTea UI interacts strictly with the `BrowserEngine` interface abstraction, isolating platform-specific dependencies.

---

## 2. Platform-by-Platform Investigation

### A. Windows

#### Option 1: Microsoft Edge WebView2 via `flutter_inappwebview_windows` / `webview_windows`
- **Underlying Engine:** Chromium-based Microsoft Edge WebView2 runtime.
- **Feasibility:** High. WebView2 is preinstalled on Windows 11 and Windows 10 (via automatic servicing). Does not bloat app installer size.
- **Maintenance Status:** Actively maintained by Microsoft; Flutter bindings are actively updated.
- **Licensing:** The Flutter packages are MIT or Apache-2.0. The WebView2 SDK and evergreen runtime are freely redistributable under Microsoft Software License terms.
- **Capabilities:**
  - Full DOM access, script evaluation, network interception, devtools protocol support.
  - Inline rendering inside the Flutter window tree.
- **Limitations:** Windows-only; requires NuGet CLI / MSVC build tools during project compilation.

#### Option 2: Chromium Embedded Framework (CEF) via `webview_cef`
- **Underlying Engine:** CEF binaries compiled for x86_64/arm64.
- **Feasibility:** Moderate. Works via off-screen texture rendering.
- **Maintenance Status:** Community-maintained; lags behind Chromium releases.
- **Licensing:** BSD-3-Clause.
- **Limitations:** Adds 150MB+ to the app bundle size and requires custom binary distribution.

**Windows Recommendation:** Use **Microsoft Edge WebView2** (`flutter_inappwebview_windows` or `webview_windows`).

---

### B. Linux

#### Option 1: WebKitGTK (Native Linux System Web Engine)
- **Underlying Engine:** WebKitGTK (`libwebkit2gtk-4.1`).
- **Feasibility:** High for native Linux desktop distribution (Flatpak/Snap/Deb/RPM).
- **Maintenance Status:** Canonical, GNOME, and Debian primary web engine; actively maintained.
- **Licensing:** LGPL-2.1 / BSD-2-Clause. HotTea dynamically links to system WebKitGTK libraries, preserving open-source compliance without requiring proprietary relinking exceptions.
- **Capabilities:**
  - Standard compliant HTML5/CSS3/JavaScript.
  - Native integration with GTK3/GTK4 windowing system used by Flutter Linux desktop.
- **Limitations:** Inline Flutter embedding requires offscreen surface or X11/Wayland subwindow overlay. Alternatively, separate auxiliary window mode (`desktop_webview_window`) can be used for secondary browsing.

#### Option 2: CEF (`webview_cef`)
- **Underlying Engine:** Chromium Embedded Framework.
- **Feasibility:** Moderate. Off-screen texture rendering directly into Flutter `Texture` widget.
- **Maintenance Status:** Community-driven; binary builds can be brittle across diverse Linux distributions (glibc version mismatches, Wayland vs X11).
- **Licensing:** BSD-3-Clause.
- **Limitations:** High bundle size (180MB+), significant RAM footprint.

**Linux Recommendation:** Prioritize **WebKitGTK** for native lightness and distribution compatibility, using `BrowserEngine` texture/subwindow adapter.

---

### C. macOS

#### Option 1: Apple WebKit via `WKWebView` (`flutter_inappwebview` or `webview_flutter_wkwebview`)
- **Underlying Engine:** System Apple WebKit framework.
- **Feasibility:** High. Built into macOS; zero binary overhead.
- **Maintenance Status:** First-party Apple framework; Flutter plugins actively maintained.
- **Licensing:** Apache-2.0 / BSD-3-Clause for Flutter wrappers; system libraries covered by macOS system license.
- **Capabilities:**
  - Inline embedding via `AppKitView`.
  - Full cookie isolation, content blockers, script injection.
  - High energy efficiency and native macOS security sandbox integration.
- **Limitations:** Requires App Sandbox network permissions (`com.apple.security.network.client`). Requires full Xcode installation on the build host for release packaging.

**macOS Recommendation:** Use **`WKWebView`** via `flutter_inappwebview` or `webview_flutter_wkwebview`.

---

### D. Android

#### Option 1: Android System WebView (`webview_flutter_android` or `flutter_inappwebview`)
- **Underlying Engine:** Android System WebView (Chromium updated via Google Play).
- **Feasibility:** High. Standard mechanism across Android 7.0+.
- **Maintenance Status:** Officially maintained by Google and the Flutter core team.
- **Licensing:** BSD-3-Clause / Apache-2.0.
- **Capabilities:**
  - Hybrid composition and Texture Layer composition.
  - Content filtering, DOM extraction, JavaScript bridges, cookie managers.
- **Limitations:** Behavior can vary slightly depending on the user's installed Android System WebView version.

#### Option 2: Mozilla GeckoView
- **Underlying Engine:** Mozilla Gecko (Firefox core).
- **Feasibility:** Moderate to Low for Flutter. Requires custom JNI / Flutter texture embedding.
- **Licensing:** MPL-2.0.
- **Limitations:** Heavy APK size (+60MB), high maintenance cost for an MVP.

**Android Recommendation:** Use **Android System WebView** (`flutter_inappwebview` / `webview_flutter_android`).

---

### E. iOS

#### Option 1: Apple WebKit (`WKWebView`)
- **Underlying Engine:** Apple WebKit.
- **Feasibility:** High. This is the **only permissible browser engine on iOS** under Apple App Store Review Guideline 2.5.6.
- **Maintenance Status:** First-party Apple framework.
- **Licensing:** BSD-3-Clause / Apache-2.0 for Flutter wrappers.
- **Capabilities:**
  - Inline rendering via `UiKitView`.
  - Native gesture recognition and hardware acceleration.
- **Limitations:** JIT-disabled in WebKit for third-party apps without special entitlement; process termination under extreme memory pressure.

**iOS Recommendation:** Use **`WKWebView`** exclusively.

---

## 3. Separation of Concerns & Decoupling Strategy

To guarantee that the shared UI code (tabs, address bar, split-view workspace, bookmarks, history, AI assistant) remains 100% platform-agnostic:

1. **`BrowserEngine` Contract**:
   All UI widgets only interact with `lib/features/browser/domain/browser_engine.dart`.
2. **Conditional Platform Registrars**:
   A factory registry loads the appropriate adapter at runtime:
   - `WindowsBrowserAdapter` (WebView2)
   - `LinuxBrowserAdapter` (WebKitGTK / CEF)
   - `MacOSBrowserAdapter` (WKWebView)
   - `AndroidBrowserAdapter` (Android WebView)
   - `IosBrowserAdapter` (WKWebView)
   - `MockBrowserEngine` (Tests, CI, and environments without native display runtimes)
