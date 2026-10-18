# Prioritized MVP Implementation Plan (Target: October 31, 2026)

This roadmap outlines the milestones and engineering phases required to deliver a demonstrable, privacy-first, cross-platform MVP of **HotTea**.

---

## 1. Timeline & Milestone Overview

| Milestone | Target Window | Primary Deliverable | Validation Criteria |
| :--- | :--- | :--- | :--- |
| **M0: Foundation & Environment** | Oct 18 – Oct 20 | Multi-platform Flutter scaffold, architecture contracts, CI foundation. | `flutter test` and `dart analyze` passing; clean builds across Web/Desktop. |
| **M1: Browser Engine Abstraction** | Oct 21 – Oct 24 | `BrowserEngine` platform implementations (macOS WKWebView, Windows WebView2, Android, Linux). | Browsing URLs, tab management, back/forward navigation, DOM text extraction. |
| **M2: Local Persistence & Notes** | Oct 25 – Oct 26 | Local SQLite/Isar database for bookmarks, history metadata, and Markdown research notes. | Local CRUD operations with zero cloud dependencies; offline-first guarantee. |
| **M3: Provider-Agnostic AI Gateway** | Oct 27 – Oct 28 | AI Gateway interface with local runtime stub + OpenAI/Anthropic/Ollama adapters. | Explicit user consent dialogs before external transmission; verified zero silent fallback. |
| **M4: Research Workspace Integration** | Oct 29 – Oct 30 | Split-screen workspace: page clipping, AI summarization of extracted page text, side-by-side notes. | End-to-end user workflow: Browse -> Clip DOM -> Summarize with AI -> Save to Note. |
| **M5: MVP Hardening & Verification** | Oct 31, 2026 | Polish, platform packages, documentation, security self-audit, demo release. | Demonstrable MVP packaged and verified against all 10 Core Requirements. |

---

## 2. Detailed Phase Breakdown

### Phase 1: Browser Engine Integrations (M1)
1. Implement `MacOSBrowserAdapter` using `flutter_inappwebview` or `webview_flutter_wkwebview`.
2. Implement `WindowsBrowserAdapter` using `webview_windows` or `flutter_inappwebview_windows`.
3. Implement `AndroidBrowserAdapter` and `IosBrowserAdapter`.
4. Provide Linux WebKitGTK / CEF adapter and maintain `MockBrowserEngine` for headless CI.
5. Implement safe, sandboxed `extractPageContent()` method that retrieves plain text / markdown from the rendered DOM for research analysis without exposing cookies or credentials.

### Phase 2: Local Persistence Layer (M2)
1. Evaluate SQLite (via `sqflite` / `sqlite3`) vs `isar` for structured local storage.
2. Define domain schemas:
   - `BookmarkEntity` (URL, title, timestamp, tags).
   - `HistoryEntity` (URL, title, lastVisitedAt, visitCount).
   - `ResearchNoteEntity` (id, title, markdownContent, sourceUrl, citations, createdAt, updatedAt).
3. Ensure zero cloud synchronization in the default tier.

### Phase 3: AI Gateway & Privacy Boundary (M3)
1. Implement `AiGateway` with strict routing:
   - `LocalInferenceEngine` (Ollama local REST / llama.cpp runtime).
   - `ExternalCloudGateway` (OpenAI / Anthropic / OpenRouter API).
2. Implement `TransmissionConsentDialog`:
   - Shows exact domain, payload size, and data scope (prompt text vs extracted page context).
   - Requires explicit click before any network dispatch.
3. Automated unit test ensuring: If local model fails or is offline, the gateway raises `LocalInferenceFailureException` and **NEVER** automatically re-routes to a cloud model.

### Phase 4: Split-View Research Workspace (M4)
1. Split-view layout with draggable divider:
   - Left: Multi-tab web browser.
   - Right: Collapsible research canvas (Notes & AI Assistant).
2. Action: "Clip to Notes" button in the address bar that captures active page title, URL, and selected text into the current note.
3. Action: "Ask AI about this page" that extracts readable page text, prompts the user for external transmission approval if using cloud AI, and streams responses directly into the research canvas.

### Phase 5: Verification & Delivery (M5)
1. Run automated integration test suite across platforms.
2. Conduct security self-check against `.qvault` threat model principles.
3. Prepare MVP release notes and demonstration artifacts.
