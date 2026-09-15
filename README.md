# Crash Log Decoder

Internal support/engineering tool. Takes the `.enc` file a user's device produces
via **Help & Support → Share Crash Logs**, decrypts it entirely in the browser,
unzips it, and renders the plaintext crash/API-error entries in a readable UI.

Built as a Flutter Web app — no backend, no analytics, nothing uploaded anywhere.
Decryption, unzip, and parsing all happen client-side.

## Running it

```bash
flutter pub get
flutter run -d chrome
```

Or build a static bundle you can host or hand around as a folder:

```bash
flutter build web
```

The build output lands in `build/web/` and can be opened directly or served with
any static file server.

## Using it

1. The app boots with a default decryption private key already loaded (see
   **Private key** below) — no need to paste anything for the common case.
2. Click **Browse files…** and pick the `.enc` file (or any renamed copy of it —
   the app doesn't check the filename).
3. Browse decoded entries per log file (`crashes_api_*`, `crashes_bloc_*`,
   `crashes_ui_*`) using the tabs at the top — each is closable, and closed
   tabs can be reopened from the history menu.
4. Use the search box and severity filters on the left to narrow results, click
   a row for the full detail view, and use **Copy raw** / **View raw** when you
   need the untouched original text (e.g. to paste into a ticket).

## Private key

Crash logs are encrypted on-device with a public key served from Firebase
Remote Config (`crash_logs_public_key`). This tool needs the **matching
private key** (`crash_logs_private_key`, also in Remote Config) to decrypt them.

The current key is hardcoded in [`lib/crypto/default_key.dart`](lib/crypto/default_key.dart)
for convenience. This is a deliberate tradeoff — crash logs are diagnostic data
(device info, stack traces, already-redacted API bodies), not secrets, so the
scheme is obfuscation-grade by design on the mobile side too. It does mean:

- The key is visible to anyone with access to this repo or a build of it.
- **Keep this repo's visibility scoped accordingly**, and be mindful before
  sharing clones, forks, or build artifacts.
- If `crash_logs_public_key` is ever rotated in Remote Config, update the
  constant in `default_key.dart` to the new matching private key. Logs
  exported *before* a rotation still need the *old* key — use **Change key**
  in the app to paste it in for that session (it's kept in memory only, never
  persisted).

## Format reference

The wire format (`FLOWCLE1`: X25519 + HKDF-SHA256 + AES-256-GCM) and the
plaintext log record shapes are implemented in:

- [`lib/crypto/crash_log_decryptor.dart`](lib/crypto/crash_log_decryptor.dart) — decrypt pipeline
- [`lib/parsing/decoded_archive.dart`](lib/parsing/decoded_archive.dart) — zip unpacking
- [`lib/parsing/log_parser.dart`](lib/parsing/log_parser.dart) — record parsing

These mirror the mobile app's `crash_log_encryptor.dart` / `crash_logger_service.dart`
byte-for-byte — see the doc comments in `crash_log_decryptor.dart` for the exact
field layout if you need to change either side.

## Tests

```bash
flutter test
```

Includes a crypto round-trip test that builds a synthetic `FLOWCLE1` archive
and confirms the decrypt path recovers the original bytes, plus negative cases
(truncated file, bad magic, tampered tag, wrong key) and parser tests against
realistic log content.
