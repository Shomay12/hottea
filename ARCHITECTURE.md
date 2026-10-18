# HotTea Architecture Specification

HotTea is an open-source, local-first, privacy-focused AI browser and research workspace targeting **Windows**, **Linux**, **macOS**, **Android**, and **iOS**.

---

## 1. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           HOTTEA SHARED UI                              │
│                      (Flutter Material 3 / Dart)                        │
├───────────────────────────────────┬─────────────────────────────────────┤
│      BROWSER PRESENTATION         │      RESEARCH WORKSPACE & AI        │
│  - Tab Bar & Navigation Controls  │  - Markdown Notes Editor            │
│  - Address & Security Bar         │  - Split-Canvas Workspace Layout    │
│  - Content Viewport Widget        │  - AI Prompt & Assistant Panel      │
└─────────────────┬─────────────────┴──────────────────┬──────────────────┘
                  │                                    │
                  ▼                                    ▼
┌──────────────────────────────────┐ ┌──────────────────────────────────┐
│      BROWSER ENGINE ADAPTER      │ │       AI GATEWAY & ROUTER        │
│    (Decoupled Abstract Layer)    │ │    (Strict Privacy Boundary)     │
├──────────────────────────────────┤ ├──────────────────────────────────┤
│ `BrowserEngine` interface:       │ │ `AiGateway` interface:           │
│  - loadUrl(Uri)                  │ │  - completePrompt(...)           │
│  - goBack() / goForward()        │ │  - streamPrompt(...)             │
│  - extractPageContent()          │ │  - checkConsent(Disclosure)      │
│  - evaluateJavascript(...)       │ │  - fallbackPolicy: STRICT_LOCAL  │
└─────────────────┬────────────────┘ └─────────────────┬────────────────┘
                  │                                    │
                  ▼                                    ▼
┌──────────────────────────────────┐ ┌──────────────────────────────────┐
│   PLATFORM IMPLEMENTATIONS       │ │       INFERENCE ENGINES          │
├──────────────────────────────────┤ ├──────────────────────────────────┤
│ • macOS:   WKWebView (AppKit)    │ │ [Local Engine Tier]              │
│ • iOS:     WKWebView (UIKit)     │ │  - Ollama REST / llama.cpp       │
│ • Windows: WebView2 (Chromium)   │ │  - 100% Offline / Zero Network   │
│ • Android: System WebView        │ ├──────────────────────────────────┤
│ • Linux:   WebKitGTK / CEF       │ │ [External Cloud Tier]            │
│ • Test/CI: MockBrowserEngine     │ │  - OpenAI / Anthropic / Custom   │
│                                  │ │  - Explicit user consent modal   │
└──────────────────────────────────┘ └──────────────────────────────────┘
                  │                                    │
                  └─────────────────┬──────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     LOCAL PERSISTENCE LAYER                             │
├─────────────────────────────────────────────────────────────────────────┤
│ • SQLite / Structured Storage: History, Bookmarks, Research Notes       │
│ • Future Encrypted Container: `.qvault` (AES-256-GCM / Argon2id)        │
│ • Strict Boundary: Zero default telemetry, zero hidden sync            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Repository Layout

```
hottea/
├── .github/                 # CI/CD workflows, issue templates, linter checks
├── android/                 # Android native runner & permissions
├── ios/                     # iOS native runner & WebKit configurations
├── macos/                   # macOS native runner & App Sandbox configurations
├── windows/                 # Windows C++ runner & WebView2 dependencies
├── linux/                   # Linux GTK runner & WebKitGTK bindings
├── web/                     # Web runner & fallback preview
├── docs/                    # Architectural specs, threat models, and plans
│   ├── platform_browser_analysis.md
│   ├── threat_model_qvault.md
│   └── mvp_implementation_plan.md
├── lib/
│   ├── core/                # Core application infrastructure
│   │   ├── config/          # Privacy policies, feature flags, constants
│   │   ├── errors/          # Domain exception models
│   │   └── utils/           # Platform detection & string helpers
│   ├── features/
│   │   ├── browser/         # Decoupled browser feature
│   │   │   ├── domain/      # BrowserEngine interface, TabModel, Navigation
│   │   │   ├── data/        # History and Bookmarks repositories
│   │   │   └── presentation/# Tab bar, address bar, viewport widgets
│   │   ├── ai/              # Provider-agnostic AI Gateway
│   │   │   ├── domain/      # AiGateway contract, privacy boundaries, errors
│   │   │   ├── data/        # Local Ollama client, OpenAI/Anthropic adapters
│   │   │   └── presentation/# Assistant panel, consent dialogs, badges
│   │   ├── notes/           # Research workspace notes
│   │   │   ├── domain/      # ResearchNote entity, Markdown models
│   │   │   ├── data/        # Local SQLite / file persistence
│   │   │   └── presentation/# Split canvas, Markdown editor
│   │   └── settings/        # Privacy toggles, provider keys, engine choice
│   └── main.dart            # Application entrypoint & composition root
├── test/                    # Unit, widget, and integration tests
├── pubspec.yaml             # Project dependencies and asset definitions
├── LICENSE                  # Apache 2.0 open-source license
└── README.md                # Project documentation and quickstart
```

---

## 3. Core Architectural Principles & Invariants

### Invariant 1: Separation of Browser Engine from Shared UI
The user interface never makes calls to platform-specific WebView libraries. All navigation, DOM extraction, and event subscriptions occur through the `BrowserEngine` interface. This allows HotTea to swap or adapt browser backends (e.g., WebView2 on Windows, WKWebView on macOS/iOS, WebKitGTK on Linux) without altering a single line of UI or tab management code.

### Invariant 2: AI Gateway & Absolute Ban on Silent Fallback
Under no circumstances may a request intended for a local model automatically or silently route to an external cloud vendor. If local inference fails, an explicit `LocalInferenceFailureException` is generated. Transmission to external providers requires explicit user approval highlighting what data (prompt vs DOM content) is being transmitted and to which endpoint.

### Invariant 3: Zero-Telemetry Default
HotTea does not include third-party tracking, advertising SDKs, crash beacons, or usage analytics by default.

### Invariant 4: Standards-Based Cryptography
For the planned `.qvault` secure container:
- No proprietary or custom cryptographic algorithms.
- Industry-standard primitives: `Argon2id` for key derivation, `AES-256-GCM` or `XChaCha20-Poly1305` for authenticated encryption.
- No claims of absolute security without formal test suites and peer review.

---

## 4. Key Technical Risks & Mitigation Strategies

| Technical Risk | Impact | Likelihood | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **Linux Desktop WebView disparity** | High | High | Define a modular GTK/CEF adapter; provide headless/mock mode for CI testing; document Linux system requirements (`libwebkit2gtk-4.1`). |
| **High resource consumption with local LLMs** | High | Moderate | Support lightweight quantization (GGUF via llama.cpp / Ollama); provide clear hardware capability indicators before model load. |
| **DOM extraction security risks (XSS / Prompt Injection)** | High | Moderate | Sanitize extracted DOM text before presenting to the user or feeding to AI; run extraction in isolated contexts without cookie exposure. |
| **Platform toolchain variance across host environments** | Moderate | High | Abstract native requirements behind clean Dart interfaces; maintain multi-platform CI runners (macOS, Windows, Linux) for continuous verification. |
