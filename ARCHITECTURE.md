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
│ • Future Encrypted Container: `.tea` (AES-256-GCM / Argon2id)           │
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
│   ├── threat_model_tea.md
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
For the planned `.tea` secure container:
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

---

## 5. Phase 3: AI Gateway & Privacy Architecture

### 5.1 Layered Dataflow & Privacy Boundary
```
User Interface (Split Canvas / Mobile Action Sheet)
         │
         ▼
    AiGateway (Registry & Router)
         │
         ▼
  AiConsentPolicy (Evaluate external transmission)
    ├── If Local Execution Target:
    │     └── Disclose zero network transmission.
    └── If Remote Cloud Execution Target:
          ├── Generate ExternalTransmissionDisclosure:
          │     - Destination provider name & endpoint URL
          │     - Prompt character count
          │     - Attached research notes, snippets & source URLs
          └── Require explicit user authorization modal before HTTP request.
         │
         ▼
  AiProviderAdapter (Contract)
    ├── OpenAiChatCompletionsAdapter (Hosted HTTPS OpenAI-compatible endpoints)
    └── LocalRuntimeStubAdapter (On-device engine; throws LocalInferenceFailureException)
```

### 5.2 Key Invariants & Privacy Protections
1. **Explicit Cloud Consent**: Remote HTTP requests are blocked until the user authorizes the transmission. If the user cancels the dialog, zero bytes are transmitted over the network.
2. **Zero Silent Cloud Fallback**: Local inference (`LocalRuntimeStubAdapter`) is strictly distinguished from hosted inference (`isLocal: true, isAvailable: false`). Attempting inference on unavailable local engines explicitly fails with `LocalInferenceFailureException` and never silently redirects prompts to a hosted cloud provider.
3. **No Unconsented Data Leaks**: Research notes, webpage DOM, and cookies are never automatically or implicitly attached to AI requests. Only notes explicitly selected by the user are included.
4. **Credential Sanitation**: API keys and authorization headers are never logged to console or exposed in error messages or exception objects.
5. **Direct HTTPS Communication**: Direct requests to user-configured endpoints without telemetry, proxy intermediaries, or tracking servers.

---

## 6. Phase 4: Research Workspace & Evidence Capture

### 6.1 Extraction & Clipping Architecture
```
Browser Viewport (Platform WebView / Mock Engine)
         │
         ▼ (Evaluates self-contained JavaScript on-device)
 WebpageExtractionService
   ├── Page Title & Canonical URL (meta[rel="canonical"])
   ├── Author & Date Metadata (meta[name="author"], article:published_time, time[datetime])
   ├── Heading Structure (h1, h2, h3 tags up to 40 nodes)
   ├── Readable Main Content (cleans <script>, <style>, <nav>, <header>, <footer>)
   │     └── In-memory character safety ceiling (50,000 chars)
   └── Active User Selection (window.getSelection())
         │
         ▼
 SourceEntity & EvidenceEntity
   ├── Verbatim passage preservation (never rewritten or hallucinated)
   ├── Context heading retention (locates passage within article structure)
   ├── Source URL & title attribution (canonical when present)
   └── User annotation, tags, and research topic
         │
         ▼
 LocalPersistenceRepository (DatabaseHelper Schema v3)
   ├── Table `sources` (id, url, title, canonical_url, author, published_date, headings, extracted_text, captured_at)
   └── Table `evidence` (id, source_id, source_url, source_title, passage, context_heading, annotation, tags, topic, captured_at)
         │
         ▼
 UI Presentation (Desktop Split Canvas & Mobile Sheets)
   ├── Sub-Tab 1: Evidence Clippings (Search, filter by topic/tag, copy, edit, delete, append to note)
   ├── Sub-Tab 2: Webpage Sources (Source metadata, heading outlines, body text preview, quick clip)
   └── Sub-Tab 3: Markdown Notes (Persistent offline notes editor with evidence citation appending)
```

### 6.2 Key Invariants & Safeguards
1. **100% On-Device Extraction**: Webpage DOM extraction runs entirely within the local WebView sandbox. DOM content is never transmitted across the network merely to parse or extract it.
2. **Verbatim Preservation**: Captured evidence passages are saved exactly as selected without summarization or model rewriting. AI summaries are strictly distinguished from verified source evidence.
3. **Source Traceability**: Every evidence clipping retains a permanent, clickable reference to its original URL, title, and timestamp. If author or date metadata is missing, it remains absent rather than guessed or fabricated.
4. **Grounded AI Context Selection**: Users can select specific evidence clippings to attach as context for AI queries. When selected, the explicit Phase 3 consent boundary highlights each passage, its source URL, and its target provider before any remote transmission occurs.
5. **Schema Versioning**: Local SQLite persistence is upgraded cleanly to Schema Version 3 with dedicated indices (`idx_evidence_source_id`, `idx_evidence_captured_at`, `idx_sources_url`), preserving backward compatibility and enabling future migration to Phase 5 `.tea` encrypted vaults.

