# Threat Model & Storage Boundary Specification: `.tea`

> **Security Baseline Notice:**  
> In accordance with HotTea Core Requirement 6 & 7:  
> - **We do NOT claim that this application is secure without empirical evidence, peer review, and automated cryptographic test vectors.**  
> - **We will NEVER invent a custom cryptographic algorithm.** All cryptographic operations must rely on vetted, industry-standard primitives (e.g. libsodium, WebCrypto, or OS-native Keychain/Keystore).

---

## 1. Overview of `.tea`

The `.tea` format is a planned local-first encrypted container designed to securely store:
- User browsing session cookies, active credentials, and saved forms.
- High-sensitivity research notebooks and extracted web clippings.
- Local AI conversation history containing confidential prompt data.
- API keys and tokens for optional external AI providers.

---

## 2. Threat Model Analysis (STRIDE)

| Threat Category | Description & Attack Vector | Impact | HotTea Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **Spoofing** | Attacker substitutes a forged `.tea` archive or tampers with the container header. | Medium | **Authenticated Encryption (AEAD)** with cryptographic binding of header metadata to the cipher tag. |
| **Tampering** | Modification of encrypted blocks in transit or on disk. | High | **AES-256-GCM** or **XChaCha20-Poly1305**. Any single bit flip invalidates authentication tag; container fails to open. |
| **Repudiation** | Audit log evasion regarding when data was decrypted. | Low | Local immutable operation audit log stored within the container. |
| **Information Disclosure** | Unauthorized extraction of secrets from local disk when the computer or device is lost, stolen, or shared. | Critical | Keys derived via **Argon2id** (memory-hard KDF). Zero-knowledge design: password never written to disk. |
| **Denial of Service** | Corrupting vault headers to prevent user access. | Medium | Atomic write semantics (`.tea.tmp` -> rename) with automated snapshot backups. |
| **Elevation of Privilege** | Malicious web page in browser abusing JavaScript bridge to access vault memory. | Critical | **Strict Process Isolation:** The browser engine runs in a sandboxed process. The vault key is never exposed to the JS runtime context. |

---

## 3. Cryptographic Primitives & Specification

HotTea strictly adheres to established cryptographic standards:

1. **Key Derivation Function (KDF):**
   - **Algorithm:** `Argon2id` (RFC 9106).
   - **Parameters:** Memory size: 64 MB, Iterations: 3, Parallelism: 4 (calibrated per platform).
   - **Salt:** 32 bytes cryptographically secure random bytes generated via OS CSPRNG (`/dev/urandom` or `SecRandomCopyBytes` / `BCryptGenRandom`).

2. **Authenticated Encryption with Associated Data (AEAD):**
   - **Algorithm:** `AES-256-GCM` or `XChaCha20-Poly1305`.
   - **Nonce:** 96-bit (GCM) or 192-bit (XChaCha20) unique IV generated per block. Nonce reuse must be mathematically impossible.
   - **Tag Length:** 128-bit authentication tag.

3. **Master Key Storage & Platform Keystores:**
   - Desktop (macOS): Apple Keychain (`kSecClassGenericPassword`).
   - Desktop (Windows): Windows Credential Manager / DPAPI (`CryptProtectData`).
   - Desktop (Linux): Secret Service API (libsecret / GNOME Keyring / KWallet).
   - Mobile (Android): Android Keystore System (`KeyGenParameterSpec` backed by StrongBox / TEE).
   - Mobile (iOS): iOS Keychain Services with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.

---

## 4. Storage Boundaries & Isolation Rules

1. **Cleartext Volatile Memory Lifecycle:**
   - Decrypted vault content exists strictly in volatile RAM.
   - Sensitive memory buffers must be zeroized/overwritten immediately after use (`zeroMemory()`).
2. **Network Exemption:**
   - `.tea` containers and their derived encryption keys are **strictly local**.
   - Under no circumstances shall `.tea` raw files or decrypt keys be transmitted over the network or uploaded to any AI vendor.
3. **No Premature Implementation:**
   - Container implementation will commence only after the unified storage abstraction (`LocalPersistenceRepository`) is operational, and cryptographic unit test vectors (NIST CAVP test vectors) are integrated into CI.
