# HotTea ☕

> **An open-source, local-first, privacy-focused AI browser and research workspace.**

HotTea reimagines web research by uniting a native web browser with a local-first workspace and a provider-independent AI gateway. HotTea puts user privacy and control first: your browsing data, research notes, and AI queries stay on your machine.

---

## 🎯 Target Platforms

* **Windows** (x86_64 / arm64)
* **Linux** (x86_64 / arm64)
* **macOS** (Apple Silicon / Intel)
* **Android** (API 24+)
* **iOS** (iOS 14+)

*Project Milestone: Demonstrable MVP by October 31, 2026.*

---

## 🛡️ Core Guarantees & Privacy Commitments

1. **Vendor Independence**: No hardcoded reliance on any single AI provider.
2. **No Silent Fallback**: Local inference **never** silently falls back to cloud inference.
3. **Informed Consent**: Explicit user confirmation before prompts or page content are sent to any external server.
4. **Decoupled Architecture**: Browser engines are strictly separated from shared UI logic.
5. **Transparent Capabilities**: Clear disclosure of platform-specific features and limitations.
6. **Evidenced Security**: No unfounded security claims without reproducible tests and threat model reviews.
7. **Standard Cryptography**: Zero custom cryptographic algorithms. Industry-standard primitives only (Argon2id, AES-256-GCM / XChaCha20-Poly1305).
8. **Minimal Dependencies**: Rigorous license audit of all external packages.
9. **Zero Secret Leakage**: No API keys, credentials, or cookies committed to source control.
10. **Zero Telemetry**: No telemetry, analytics, or advertising by default.

---

## 🌐 Browser Features & Workspace Capabilities

* **Multi-Engine Web Search**: Direct address bar search via Google (default), DuckDuckGo, Bing, or Brave Search without telemetry or proxy intermediaries.
* **Multi-Tab Architecture**: Open, switch, and close isolated browser tabs with independent history, title, and loading state.
* **Private / Incognito Mode**: Isolated session tabs with disabled caching; visits and cookies are never committed to disk.
* **Session Restoration**: Option to automatically save and restore open tabs across application launches.
* **Downloads Manager**: Dedicated downloads pane with real-time progress, size metrics, cancellation, and retry.
* **Find in Page & Zoom**: In-page search highlights (`Cmd+F` / `Ctrl+F`) and smooth zoom scaling (`Cmd+=` / `Cmd+-`).
* **Interactive Navigation Error Recovery**: In-viewport error diagnostics with retry and fallback search triggers.
* **Local Research Workspace**: Side pane featuring offline Markdown notes with web clipping, bookmarked resources with filtering and "Open in New Tab", and full browsing history search.

### ⌨️ Desktop Keyboard Shortcuts

| Shortcut (macOS) | Shortcut (Windows/Linux) | Action |
| :--- | :--- | :--- |
| `Cmd + T` | `Ctrl + T` | Open new tab |
| `Cmd + Shift + N` | `Ctrl + Shift + N` | Open new private tab |
| `Cmd + W` | `Ctrl + W` | Close active tab |
| `Cmd + R` | `Ctrl + R` | Reload active page |
| `Cmd + L` | `Ctrl + L` | Focus address bar & select URL |
| `Cmd + F` | `Ctrl + F` | Open Find in Page bar |
| `Cmd + D` | `Ctrl + D` | Bookmark active page |
| `Cmd + [` | `Ctrl + [` | Navigate back |
| `Cmd + ]` | `Ctrl + ]` | Navigate forward |
| `Cmd + =` | `Ctrl + =` | Zoom in |
| `Cmd + -` | `Ctrl + -` | Zoom out |
| `Cmd + 0` | `Ctrl + 0` | Reset zoom to 100% |

---

## 🏗️ Architecture & Documentation

* **[ARCHITECTURE.md](file:///Users/quaxiom/Documents/DEVLOPMENT/Projects/HotTea/ARCHITECTURE.md)**: System design, high-level diagrams, invariants, and directory structure.
* **[Platform Browser Analysis](file:///Users/quaxiom/Documents/DEVLOPMENT/Projects/HotTea/docs/platform_browser_analysis.md)**: Feasibility, maintenance status, and licenses for browser runtimes across all 5 platforms.
* **[Threat Model & Storage Boundaries](file:///Users/quaxiom/Documents/DEVLOPMENT/Projects/HotTea/docs/threat_model_tea.md)**: Threat model and security rules for local persistence and future `.tea` encrypted containers.
* **[MVP Implementation Plan](file:///Users/quaxiom/Documents/DEVLOPMENT/Projects/HotTea/docs/mvp_implementation_plan.md)**: Prioritized roadmap targeting October 31, 2026.

---

## 🚀 Quickstart & Verification

### Prerequisites
- Flutter SDK 3.41+ (`flutter --version`)
- Dart SDK 3.11+
- For desktop native builds:
  - **macOS**: Full Xcode installation (`/Applications/Xcode.app`) and Command Line Tools.
  - **Windows**: Visual Studio 2022 with C++ desktop workload and Microsoft Edge WebView2.
  - **Linux**: Clang, CMake, GTK 3.0 development headers (`libgtk-3-dev`), WebKitGTK (`libwebkit2gtk-4.1-dev`).
  - **Android**: Android SDK & cmdline-tools.
  - **iOS**: Xcode & CocoaPods.

### Run Tests and Analysis
```bash
# Run unit and widget tests
flutter test

# Run static analysis
dart analyze
```

### Build & Run
```bash
# Run on Web (useful for cross-platform validation without native desktop toolchains)
flutter run -d chrome

# Run on macOS desktop (requires Xcode)
flutter run -d macos

# Run on Windows desktop
flutter run -d windows

# Run on Linux desktop
flutter run -d linux
```

---

## 📄 License

HotTea is licensed under the **[Apache License 2.0](file:///Users/quaxiom/Documents/DEVLOPMENT/Projects/HotTea/LICENSE)**.
# hottea
