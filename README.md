<div align="center">

🍵 HotTea

Your Browser. Your AI. Your Research. Your Data.

An open-source, privacy-first AI browser and research workspace.

Bring web browsing, AI assistance, evidence-backed research, local inference, and encrypted personal storage into one cross-platform application.

<br/>
<br/>

Browse · Research · Think · Build · Protect

</div>

⸻

🌌 What Is HotTea?

The modern browser has become the center of our digital lives. We use it to research, develop software, learn new technologies, interact with AI, and manage sensitive information.

Yet our workflows remain fragmented across browser tabs, AI chatbots, research tools, and separate applications.

HotTea aims to bring these workflows together without sacrificing user control.

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

HotTea is an open-source project to build a cross-platform browser and AI-powered research workspace using Flutter and Dart, with platform-specific browser integrations where necessary.

The long-term vision is an application where users can browse the web, work with different AI models, investigate technical topics, organize research, and protect private information from one unified workspace.

Privacy is not supposed to be a premium feature. It should be part of the architecture.

Our principle: Your data should remain under your control, and every external data transfer should be intentional and transparent.

✨ Core Features

HotTea is being developed around six major capabilities.

<table>
<tr>
<td width="50%" valign="top">

🌐 Unified Browser

A familiar browsing experience designed for research and development.

* Tab-based navigation
* Address bar and navigation controls
* Bookmarks and browsing history
* Persistent browser sessions
* Integrated research workspace

</td>
<td width="50%" valign="top">

🧠 Universal AI Gateway

A unified interface for working with different AI providers.

* Provider-independent architecture
* Hosted model API integrations
* Compatible local inference runtimes
* Model selection and configuration
* Explicit cloud-transfer consent

</td>
</tr>
<tr>
<td width="50%" valign="top">

🔬 Evidence-Backed Research

Move beyond answers that merely sound convincing.

* Save and organize research sources
* Associate notes with webpages
* Connect claims to supporting passages
* Identify conflicting or insufficient evidence
* Preserve source metadata and references

</td>
<td width="50%" valign="top">

🔐 Encrypted .tea Vaults

A planned encrypted container format for private information.

* Encrypted local research
* AI conversation storage
* Protected application data
* Versioned container format
* Explicit vault locking and unlocking

</td>
</tr>
<tr>
<td width="50%" valign="top">

🛡️ Privacy by Design

Privacy-conscious engineering built into the application.

* No telemetry by default
* No silent local-to-cloud AI fallback
* Transparent external data transfers
* User-controlled AI context sharing
* Auditable network behavior

</td>
<td width="50%" valign="top">

💻 Cross-Platform Development

One shared interface, with native integrations where necessary.

* Windows
* Linux
* macOS
* Android
* iOS

</td>
</tr>
</table>

Development note: These are project goals, not a claim that every feature is already implemented. See Development Status for the current scope.

⸻

🎯 Why HotTea?

AI is changing how we browse, research, and develop software. But adding an AI chat panel to a browser is not the entire problem.

A useful AI research environment needs to answer several questions:

* Where did this answer come from?
* Which source passage supports the claim?
* Is the information current?
* What happens when sources disagree?
* Was my private information sent to an external service?
* Can I use a local model instead?
* Where is my research data stored?
* Can I move my data without depending on one provider?

HotTea aims to make these questions part of the product’s design rather than leaving users to figure everything out themselves.

The difference

Traditional workflow	HotTea’s intended approach
Browser, AI, and notes in separate applications	An integrated research workspace
AI provider tied to a particular interface	A provider-independent AI gateway
Answers accompanied by generic links	Claims connected to relevant evidence
Cloud processing often treated as the default	Explicit control over local and cloud inference
Private information scattered across applications	A planned, encrypted local vault
Platform-specific application behavior	Shared Flutter UI with native integrations

These are architectural goals. Their effectiveness must be demonstrated through implementation, testing, and independent evaluation.

⸻

🏗️ Architecture

HotTea is being designed as a modular application. The shared UI should not need to know the internal details of a particular browser engine, AI provider, or storage implementation.

flowchart TB
    USER["User"]
    subgraph APP["HotTea Application"]
        UI["Flutter Interface"]
        subgraph WORKSPACE["Workspace"]
            BROWSER["Browser"]
            RESEARCH["Research Workspace"]
            ASSISTANT["AI Assistant"]
        end
        subgraph CORE["Shared Core"]
            ENGINE["Browser Engine Interface"]
            GATEWAY["AI Gateway"]
            PRIVACY["Privacy Controls"]
            STORAGE["Storage Layer"]
        end
        subgraph DATA["Local Data"]
            NOTES["Research Notes"]
            HISTORY["Bookmarks & History"]
            VAULT["Encrypted .tea Vault - Planned"]
        end
    end
    subgraph RUNTIME["External Integrations"]
        WEB["Platform Browser Engines"]
        LOCAL["Local AI Runtime"]
        CLOUD["Optional Hosted AI APIs"]
    end
    USER --> UI
    UI --> WORKSPACE
    BROWSER --> ENGINE
    ASSISTANT --> GATEWAY
    RESEARCH --> STORAGE
    ENGINE --> WEB
    GATEWAY --> LOCAL
    GATEWAY --> PRIVACY
    PRIVACY -. "Explicitly authorized requests" .-> CLOUD
    STORAGE --> NOTES
    STORAGE --> HISTORY
    STORAGE -. "Future encrypted storage" .-> VAULT
    classDef planned stroke-dasharray: 5 5
    class VAULT planned

Architectural principles

1. Separation of concerns

The UI, browser engine, AI gateway, and persistence layer should remain separate components with clear interfaces.

2. Platform-specific integrations

Flutter provides the shared interface, but browser functionality requires suitable native integrations. Not every platform exposes the same capabilities.

3. Provider independence

AI providers should be replaceable without redesigning the entire application.

4. Local-first data handling

Local storage should be the default for supported personal data. Cloud synchronization should not be required for core local workflows.

5. Explicit trust boundaries

The application should distinguish between local processing, browser activity, and requests sent to external AI or search providers.

6. Verifiable security

Security claims should be supported by tests, documented assumptions, and appropriate reviews.

⸻

🖥️ Cross-Platform Strategy

HotTea targets five operating systems through a shared Flutter application interface.

Platform	Intended browser integration	Current status
macOS	WebKit or another suitable native integration	Under development
Windows	Microsoft Edge WebView2 or a suitable alternative	Under development
Linux	WebKitGTK or a suitable Chromium-based integration	Under investigation
Android	Android System WebView	Under development
iOS	Apple WebKit through WKWebView	Under development

A common UI does not mean that every browser engine behaves identically.

HotTea will need platform-specific implementations for browser sessions, navigation, permissions, packaging, and operating-system security features.

Linux desktop support is a particular engineering consideration because browser integration and native dependencies differ from those on the other platforms.

The objective is a genuinely functional application on each supported platform, not merely five generated project directories.

⸻

🧠 AI Gateway

HotTea is intended to provide a unified interface for different AI models.

Instead of tightly coupling the application to one vendor, the AI gateway will separate the user interface from model-provider implementations.

                 User Request
                      |
                      v
                AI Gateway
                      |
                      v
             Privacy & Policy Check
                      |
                      v
              Provider Selection
                      |
             +--------+--------+
             |                 |
             v                 v
       Local Runtime      Hosted Provider
             |                 |
             v                 v
       Local Inference    Authorized API
             |                 |
             +--------+--------+
                      |
                      v
                AI Response

The gateway is intended to support:

* Multiple hosted model providers.
* Compatible local inference runtimes.
* Provider-specific configuration.
* Clear error handling.
* Model selection and task routing.
* Usage and cost reporting where supported.
* Explicit disclosure before sensitive context leaves the device.

Local means local

A particularly important design requirement is that a failed local model request must not silently become a cloud request.

If the local runtime is unavailable, HotTea should explain the problem and let the user decide what happens next.

A private request should not be sent to an external provider simply because that provider is easier to reach.

⸻

🔬 Evidence-Backed Research

Research assistance should do more than generate plausible paragraphs.

HotTea aims to build a research workflow that preserves the connection between answers and their sources.

Intended workflow

Research Question
       |
       v
Source Retrieval
       |
       v
Relevant Passage Extraction
       |
       v
Evidence Organization
       |
       v
AI-Assisted Analysis
       |
       v
Claim-Level References
       |
       v
Research Notes & Export

The research workspace is intended to support:

* Saving webpages and source metadata.
* Organizing notes around research questions.
* Associating generated claims with supporting passages.
* Identifying unsupported claims.
* Recording conflicting evidence.
* Preserving publication dates where available.
* Exporting research notes and references.

A citation is not proof that a claim is correct. Source quality, relevance, publication date, and contradictory evidence still matter.

The goal is to make AI-assisted research easier to inspect and reproduce, not to manufacture certainty.

⸻

🔐 The .tea Encrypted Vault

HotTea is planned to have its own encrypted container format using the .tea file extension.

Example:

HotTea/
├── research.tea
├── private_workspace.tea
└── browser_profile.tea

The long-term goal is to allow users to store supported private data in encrypted containers they can manage themselves.

Potential contents include:

* Research notes and saved sources.
* AI conversation histories.
* Application preferences.
* Supported browser data and session information.

Security design principles

The format will require a documented specification and a clearly defined threat model before being treated as secure.

The design will evaluate:

* Established authenticated-encryption algorithms.
* Password-based key derivation using a vetted implementation.
* Key management and password changes.
* Integrity verification and tamper detection.
* Versioned file-format metadata.
* Crash-safe writes and recovery.
* Data export and migration.
* Protection against plaintext leakage outside the vault.

The implementation should use established cryptographic libraries rather than a custom encryption algorithm.

Important: .tea is a planned format, not a completed security feature. Encrypting a container does not automatically protect cookies, caches, temporary files, or browser data stored elsewhere. Protection of an unlocked vault also depends on the security of the running application and operating system.

⸻

🛡️ Privacy Principles

Privacy must be implemented as observable behavior, not just described in a README.

HotTea’s intended principles are:

Principle	Intended behavior
Local-first	Keep supported personal data on the device by default
No default telemetry	Do not collect application usage telemetry by default
Transparent cloud access	Disclose external data transfers
No silent fallback	Never silently move a local request to a cloud provider
User-controlled context	Require authorization before sharing sensitive page content
Minimal collection	Collect only what is necessary for the requested operation
Auditable behavior	Make network activity and provider integrations testable
Honest security claims	Document limitations and verify protections before claiming them

These principles do not guarantee that external websites cannot track users or that malware cannot access information while a vault is unlocked.

HotTea must also account for the behavior of browser engines, search providers, operating systems, and external websites.

Privacy-conscious software should explain its boundaries rather than pretend those boundaries do not exist.

⸻

🧰 Technology Stack

Component	Technology	Purpose
Application UI	Flutter	Shared cross-platform interface
Programming language	Dart	Application and domain logic
Browser integration	Platform-specific engines	Web rendering and browser functionality
AI architecture	Provider-independent gateway	Unified model access
Local inference	Compatible local runtimes	On-device model execution
Persistence	Local database and repositories	Bookmarks, history, and research data
Encrypted storage	Planned .tea format	Protected local data
Version control	Git	Source history and collaboration
Continuous integration	Planned automation	Reproducible builds and tests

Dependencies will be selected based on compatibility, maintenance, security, and license requirements.

⸻

🚀 Getting Started

HotTea is in early development. The following instructions apply to the initial Flutter project and do not imply that all browser or AI functionality is ready.

Prerequisites

Install:

* Flutter SDK
* Dart SDK
* Git
* A supported development environment for your target platform.

Native builds may additionally require:

* macOS and iOS: Full Xcode installation and configuration.
* Android: Android SDK, command-line tools, and the required build tools.
* Windows: Windows desktop development tooling.
* Linux: Flutter desktop prerequisites and the native libraries required by the selected browser integration.

Consult the official Flutter documentation for platform-specific requirements.

1. Clone the repository

git clone <YOUR_GITHUB_REPOSITORY_URL>
cd HotTea

Replace the placeholder with the actual repository URL.

2. Install dependencies

flutter pub get

3. Verify the environment

flutter doctor -v

Resolve the issues relevant to your target platform.

4. Run tests and static analysis

flutter test
dart analyze

5. Launch the application

For macOS, assuming the full Xcode environment is configured:

flutter run -d macos

For web development and UI previews:

flutter run -d chrome

For Android, Windows, or Linux, first ensure that the corresponding toolchain and target are available.

6. Build the web preview

flutter build web

This builds the Flutter web application. It does not establish that native browser integrations work or that the web build provides the same security guarantees as a native application.

⸻

📦 Installation and Distribution

HotTea plans to support straightforward installation on desktop platforms.

Platform	Intended distribution
macOS	DMG and potentially Homebrew Cask
Linux	AppImage and potentially Debian packages
Windows	Native installer and potentially WinGet

Package-manager installation will become available only after the corresponding packages have been built, published, and tested.

The project also aims to establish automated release builds, artifact checksums, and appropriate signing and verification procedures.

These distribution methods are planned, not currently published installation channels.

⸻

🗺️ Roadmap

HotTea is being developed incrementally, prioritizing the riskiest engineering work first.

Phase 1: Foundation

* Initialize the Flutter project.
* Create the initial repository structure.
* Define the browser-engine interface.
* Define the AI gateway interface.
* Add initial architecture documentation.
* Establish an initial test suite.
* Validate the development environment for all target platforms.

Phase 2: Browser MVP

* Integrate a real browser engine.
* Implement URL navigation and browser controls.
* Implement tab management.
* Add loading and navigation error handling.
* Implement bookmarks and browsing history.
* Validate real browsing on supported platforms.

Phase 3: AI Gateway (Implemented & Verified)

* [x] Provider-independent AI interface (`AiGateway`, `AiRequest`, `AiResponse`, `AiProviderAdapter`).
* [x] Hosted AI provider: OpenAI-compatible chat completions adapter (`OpenAiChatCompletionsAdapter`) with configurable base URL, model, timeouts, and sanitized errors.
* [x] Explicit Cloud Consent: Dialog disclosing provider, endpoint, prompt length, and attached research notes + URLs prior to transmission.
* [x] Local runtime modeling (`LocalRuntimeStubAdapter`) with absolute ban on silent cloud fallback (`LocalInferenceFailureException`).
* [x] Research workspace integration: Explicit user selection of research notes as grounded context with preserved source URLs.
* [x] Zero telemetry, zero plaintext credential leaks in logs or exceptions, and direct HTTPS endpoints.
* [x] Validated across 56 automated tests (14 AI tests), clean `flutter analyze`, and successful builds on Web and macOS.

Phase 4: Research Workspace & Evidence Capture (Core Milestones Implemented)

* [x] On-device webpage content extraction (`WebpageExtractionService`): title, canonical URL, author, date, headings, readable main text (cleaned & capped at 50,000 chars), and active selection.
* [x] Verbatim evidence clipping (`EvidenceEntity`): capture exact text passages, context headings, source URLs, timestamps, user annotations, tags, and topics without AI rewriting.
* [x] Webpage source metadata persistence (`SourceEntity`): permanent record of visited pages, outlines, and full extracted text.
* [x] Local storage integration (SQLite Schema Version 3 & in-memory): dedicated `sources` and `evidence` tables with query, tag, and topic filtering.
* [x] Research Workspace UI: 3-subtab interface for Evidence Clippings, Webpage Sources, and Markdown Notes with responsive desktop split canvas and mobile action sheets.
* [x] Grounded AI context integration: selective attachment of individual evidence passages to AI queries with preserved source attribution and explicit consent disclosure.
* [ ] Advanced research report export (Markdown/HTML bundle).
* [ ] Multi-document cross-source contradiction detection.

Phase 5: .tea Vault

* Finalize the vault specification.
* Define the threat model.
* Implement a minimal encrypted-container prototype.
* Test password handling and tamper detection.
* Implement crash-safe writes.
* Investigate browser-profile integration.
* Audit plaintext storage boundaries.

Phase 6: Privacy and Distribution

* Add privacy-focused automated tests.
* Audit outbound network behavior.
* Establish cross-platform CI.
* Add reproducible release builds.
* Investigate desktop package distribution.
* Document supported platforms and known limitations.
* Arrange security review before making strong security claims.

Roadmap items will be updated as implementation and testing progress.

⸻

🧪 Testing and Quality

HotTea should be evaluated through more than successful compilation.

The project aims to test:

Application quality

* Widget and unit tests.
* Navigation behavior.
* Persistence and recovery.
* Error handling.

Cross-platform compatibility

* Native build success.
* Application launch.
* Real webpage rendering.
* Browser navigation.
* Platform-specific behavior.

AI behavior

* Provider error handling.
* Explicit routing behavior.
* Cloud-transfer consent.
* Prevention of silent fallback.

Research quality

* Source-reference correctness.
* Claim-to-passage traceability.
* Unsupported-claim handling.
* Conflicting-source behavior.

Storage security

* Incorrect-password handling.
* Authentication and tamper detection.
* Interrupted writes.
* Data migration and recovery.
* Plaintext leakage checks.

Testing plans are not evidence that these tests have already been implemented or passed.

⸻

🤝 Contributing

HotTea is intended to be an open-source project. Contributions that improve its functionality, architecture, privacy, security, accessibility, and documentation are welcome.

How to contribute

1. Fork the repository.
2. Create a feature branch.
3. Make a focused change.
4. Add or update tests where appropriate.
5. Run the available tests and static analysis.
6. Submit a pull request describing the change and its limitations.

Example:

git checkout -b feature/your-feature
git add .
git commit -m "feat: describe your change"
git push origin feature/your-feature

Before contributing, review the existing architecture and avoid introducing dependencies without a clear technical justification.

Security-related changes should include a description of the relevant threat model and tests.

Please report suspected security vulnerabilities privately through a documented security-reporting channel rather than publishing exploitable details in an ordinary issue.

⸻

📜 License

HotTea’s initial repository is licensed under the Apache License 2.0.

See LICENSE for the complete terms.

Third-party dependencies, browser engines, model runtimes, and model weights may have separate licensing requirements. Those requirements must be reviewed independently.

⸻

⚠️ Development Status

HotTea is an early-stage open-source project under active development.

The initial Flutter project, foundational interfaces, documentation, and basic tests have been created. The initial web build has also been reported as successful.

However, the project is not yet a completed cross-platform browser.

Real browser integrations, functional AI-provider connections, the encrypted .tea vault, and production distribution remain implementation and validation tasks.

Platform support will be described according to what has actually been built and tested.

Use this project as experimental software until its functionality and security have been independently evaluated.

⸻

💡 The Long-Term Vision

HotTea is an attempt to rethink how a browser, AI assistant, and research environment can work together.

Not another AI wrapper.

Not another collection of disconnected tools.

A transparent, modular, privacy-conscious workspace that gives users more control over their browsing, research, and AI workflows.

The long-term goal is simple:

Make the web more useful without making the user surrender control of their data.

<div align="center">

🍵 HotTea

Browse with context. Research with evidence. Keep control.

Open source · Local first · Built for research

</div>
