# Contributing to CrispyTivi

Welcome! CrispyTivi is a passion project and contributions of all
kinds are appreciated — whether it's reporting a bug, testing on a
platform we don't have access to, improving documentation, or
submitting a pull request.

## How to Contribute

### Report Bugs

Found something broken? [Open an issue](../../issues/new?template=bug_report.md)
with:

- The platform and OS version you're using
- Steps to reproduce the problem
- What you expected vs. what actually happened
- Screenshots or logs if available

### Test on Your Devices

We support 7 platforms but don't have daily access to all of them.
Running a build on your device and reporting what works (or doesn't)
is incredibly valuable. Platforms where we especially need testers:

- macOS and iOS
- Linux (various distros)
- Android TV and Fire TV devices
- Different Android phone and tablet models

### Submit a Pull Request

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Make your changes following the guidelines below
4. Push to your fork: `git push origin feat/my-feature`
5. Open a pull request against `main`

### Improve Documentation

Spotted a typo? Know a better way to explain something? Documentation
PRs are always welcome and don't require setting up the full
development environment.

---

## Development Setup

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) 3.7+
- [Rust](https://rustup.rs/) stable toolchain
- Platform-specific tools:
  - **Windows:** Visual Studio with C++ workload
  - **macOS:** Xcode
  - **Linux:** `clang`, `cmake`, `ninja-build`, `pkg-config`,
    `libgtk-3-dev`, `libmpv-dev`
  - **Android:** Android SDK, NDK, `cargo-ndk`

### First-Time Setup

```bash
# Clone your fork
git clone https://github.com/<your-username>/CrispyTivi.git
cd CrispyTivi

# Build the Rust core
cd rust && cargo build --release && cd ..

# Install Flutter dependencies and run code generation
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Verify everything works
cd rust && cargo test && cd ..
flutter test
flutter analyze
```

### Running Locally

```bash
# Native (Windows, macOS, Linux)
flutter run -d windows

# Web (start Rust server first)
cargo run -p crispy-server --manifest-path rust/Cargo.toml
flutter run -d chrome --web-port 3000
```

---

## Areas We Need Help

If you have expertise in any of these areas, your contributions
would be especially impactful:

- **Flutter / Dart** — UI patterns, Riverpod state management,
  platform channel integration
- **Rust** — Core engine, FFI bridge, performance optimization
- **TV app development** — Android TV, Fire TV, D-pad focus
  navigation, remote control UX
- **Media streaming** — IPTV protocols, M3U/Xtream edge cases,
  video codec issues
- **Cross-platform testing** — macOS, iOS, Linux, various Android
  devices

---

## Commit Convention

We enforce **Conventional Commits**:

```text
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type       | Purpose                               |
| ---------- | ------------------------------------- |
| `feat`     | New feature                           |
| `fix`      | Bug fix                               |
| `refactor` | Code restructure (no behavior change) |
| `test`     | Adding or updating tests              |
| `docs`     | Documentation only                    |
| `chore`    | Build, CI, tooling changes            |
| `perf`     | Performance improvement               |

### Scopes

Use feature names: `iptv`, `player`, `settings`, `config`, `core`,
`theme`, `vod`, `epg`, `dvr`, `server`.

### Examples

```text
feat(iptv): add M3U playlist parser with Isolate support
fix(player): resolve aspect ratio on Android TV
test(config): add ConfigService deep-merge edge cases
docs(core): update architecture documentation
```

## Branch Naming

```text
<type>/<short-description>
```

Examples: `feat/m3u-parser`, `fix/epg-cache-refresh`,
`test/config-service`.

---

## Development Rules

### TDD Is Mandatory

Every logic change must follow Red-Green-Refactor:

1. Write a **failing test** first
2. Implement **minimum code** to pass
3. **Refactor** for clarity
4. Verify **all tests pass** before committing

### Zero Hardcoded Values

- All strings in `AppConfig` or `l10n`
- All colors via `Theme.of(context).colorScheme.*`
- All dimensions in `core/theme/` constants
- All API URLs in `AppConfig.api.baseUrl`

### Architecture Compliance

- Domain layer has **zero dependencies** on Flutter or infra packages
- Presentation uses **Riverpod providers** only — no `setState` for
  business logic
- All business logic lives in Rust (`crispy-core`), not in Dart

### Code Style

- Line length: **80 characters**
- Trailing commas: **mandatory** on all argument lists
- Run `flutter analyze` before every commit
- Run `cd rust && cargo fmt --all && cargo clippy --workspace -- -D warnings`
  before every commit

---

## Pull Request Checklist

- [ ] Tests written before implementation (TDD)
- [ ] All tests pass (`flutter test` and `cd rust && cargo test`)
- [ ] `flutter analyze` reports zero issues
- [ ] `cargo clippy` reports zero warnings
- [ ] Code is formatted (`dart format lib/ test/` and `cargo fmt`)
- [ ] Conventional commit message
- [ ] No hardcoded values
- [ ] Documentation updated if public API changed

---

## License

By contributing to CrispyTivi, you agree that your contributions
are licensed under the same [CC BY-NC-SA 4.0](LICENSE.md) terms
as the rest of the project. See [NOTICE.md](NOTICE.md) for
additional details on contribution licensing.
