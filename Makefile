# ─────────────────────────────────────────────────────
# CrispyTivi — Developer Makefile
# ─────────────────────────────────────────────────────

.PHONY: help setup hooks test analyze build-windows \
        build-linux build-android build-macos \
        build-ios build-web build-server \
        release-windows release-linux release-android release-web \
        rust-test rust-build codegen clean \
        check fix rust-check rust-fix flutter-check flutter-fix

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*## "}; \
	         {printf "  \033[36m%-20s\033[0m %s\n", \
	         $$1, $$2}'

# ── Setup ──────────────────────────────────────────

setup: hooks ## Install all dependencies
	flutter pub get

hooks: ## Install pre-commit hook (fmt + clippy + analyze)
	git config core.hooksPath .githooks
	@echo "Pre-commit hook activated (.githooks/pre-commit)"
	@echo ""
	@echo "Rust targets (install as needed):"
	@echo "  rustup target add aarch64-linux-android"
	@echo "  rustup target add armv7-linux-androideabi"
	@echo "  rustup target add x86_64-linux-android"
	@echo "  rustup target add aarch64-apple-darwin"
	@echo "  rustup target add x86_64-apple-darwin"
	@echo "  rustup target add aarch64-apple-ios"
	@echo "  cargo install cargo-ndk"

# ── Quality ────────────────────────────────────────

check: rust-check flutter-check ## Full check: Rust (fmt+clippy+test) + Flutter (format+analyze+test)

fix: rust-fix flutter-fix ## Auto-fix all fixable issues in both stacks

rust-check: ## Rust: fmt check + clippy + test
	cd rust && cargo fmt --all -- --check
	cd rust && cargo clippy --workspace -- -D warnings
	cd rust && cargo test --workspace

rust-fix: ## Rust: auto-format + clippy fix
	cd rust && cargo fmt --all
	cd rust && cargo clippy --workspace --fix --allow-dirty --allow-staged -- -D warnings

flutter-check: ## Flutter: format check + analyze + test
	dart format --set-exit-if-changed lib/ test/
	flutter analyze
	flutter test

flutter-fix: ## Flutter: auto-format + dart fix
	dart format lib/ test/
	dart fix --apply

# ── Testing ────────────────────────────────────────

test: rust-test flutter-test ## Run all tests

rust-test: ## Run Rust tests
	cd rust && cargo test --workspace

flutter-test: ## Run Flutter tests
	flutter test

analyze: ## Run Flutter static analysis
	flutter analyze

check-boundary: ## Check architecture boundary violations
	dart run scripts/check_boundary.dart

# ── Rust ───────────────────────────────────────────

rust-build: ## Build Rust FFI for current platform
	bash scripts/build_rust.sh auto release

rust-build-debug: ## Build Rust FFI (debug)
	bash scripts/build_rust.sh auto debug

rust-server: ## Build and run the Rust server
	cd rust && cargo run -p crispy-server

# ── Codegen ────────────────────────────────────────

codegen: ## Run flutter_rust_bridge codegen
	flutter_rust_bridge_codegen generate

# ── Platform Builds ────────────────────────────────

build-windows: ## Build Windows release
	flutter build windows --release

build-linux: ## Build Linux release
	flutter build linux --release

build-android: ## Build Android APK
	bash scripts/build_rust.sh android
	flutter build apk --release

build-macos: ## Build macOS release
	bash scripts/build_rust.sh macos
	flutter build macos --release

build-ios: ## Build iOS (no codesign)
	bash scripts/build_rust.sh ios
	flutter build ios --no-codesign

build-web: ## Build Flutter web
	flutter build web --release

build-server: ## Build Rust server binary
	bash scripts/build_rust.sh server

# ── Run ────────────────────────────────────────────

run-windows: ## Run on Windows
	flutter run -d windows

run-web: ## Run on Chrome
	flutter run -d chrome --web-port 3000

run-linux: ## Run on Linux
	flutter run -d linux

# ── Release (local convenience) ───────────────────

release-windows: build-windows ## Build Windows installer (requires Inno Setup)
	iscc scripts/inno_setup.iss

release-linux: build-linux ## Build Linux AppImage
	bash scripts/build_appimage.sh $(shell grep 'version:' pubspec.yaml | head -1 | awk '{print $$2}')

release-android: ## Build Android APK + AAB
	bash scripts/build_rust.sh android
	flutter build apk --release
	flutter build appbundle --release

release-web: build-web ## Zip web build
	cd build/web && zip -r ../../CrispyTivi-web.zip .

# ── Clean ──────────────────────────────────────────

clean: ## Clean all build artifacts
	flutter clean
	cd rust && cargo clean
	@echo "Cleaned Flutter + Rust artifacts"
