# Contributing to HotTea

Thank you for your interest in contributing to HotTea! As an open-source, privacy-first browser and research workspace, we welcome contributions that strengthen user privacy, improve performance, expand platform support, and refine developer documentation.

---

## Code of Conduct & Core Values

1. **User Control**: Every network interaction and data storage operation must respect the user's intent. Never introduce silent background uploads, telemetry, or hidden analytics.
2. **Fact-Based Claims**: Do not overstate security guarantees. Distinguish implemented features from experimental or planned capabilities.
3. **High Code Quality**: Ensure new features are covered by automated unit/widget tests and pass `flutter analyze` without warnings.

---

## Development Workflow

### 1. Fork & Branch

Fork the repository on GitHub (`https://github.com/Shomay12/hottea`) and create a feature branch:

```bash
git checkout -b feature/my-feature-name
```

### 2. Local Setup & Testing

Before submitting changes, run the test suite and static analysis locally:

```bash
flutter pub get
flutter test
flutter analyze
```

### 3. Commit Guidelines

Use clear, descriptive commit messages following the Conventional Commits style:

* `feat: add DuckDuckGo custom instant answer toggle`
* `fix: correct iOS safe area top offset in address bar`
* `docs: update build instructions for Ubuntu 24.04`
* `test: add regression test for private browsing history isolation`

### 4. Submitting a Pull Request

* Push your branch to your fork:
  ```bash
  git push origin feature/my-feature-name
  ```
* Open a Pull Request against the `main` branch of `Shomay12/hottea`.
* Describe what your PR accomplishes, how it was verified, and any potential side effects.

---

## Security Vulnerability Reporting

If you identify a security issue, vulnerability, or potential privacy leak:

* **Do not** file a public GitHub issue detailing exploitable vectors.
* Report details securely to the maintainers via GitHub's Private Vulnerability Reporting tab at `https://github.com/Shomay12/hottea/security/advisories`.
