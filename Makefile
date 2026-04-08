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
	cd app/flutter && flutter pub get

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
	cd app/flutter && dart format --set-exit-if-changed lib/ test/
	cd app/flutter && flutter analyze
	cd app/flutter && flutter test

flutter-fix: ## Flutter: auto-format + dart fix
	cd app/flutter && dart format lib/ test/
	cd app/flutter && dart fix --apply

# ── Testing ────────────────────────────────────────

test: rust-test flutter-test ## Run all tests

rust-test: ## Run Rust tests
	cd rust && cargo test --workspace

flutter-test: ## Run Flutter tests
	cd app/flutter && flutter test

analyze: ## Run Flutter static analysis
	cd app/flutter && flutter analyze

check-boundary: ## Check architecture boundary violations
	cd app/flutter && dart run tool/check_boundary.dart

# ── Rust ───────────────────────────────────────────

rust-build: ## Build Rust FFI for current platform
	bash scripts/build_rust.sh auto release

rust-build-debug: ## Build Rust FFI (debug)
	bash scripts/build_rust.sh auto debug

rust-server: ## Build and run the Rust server
	cd rust && cargo run -p crispy-server

# ── Codegen ────────────────────────────────────────

codegen: ## Run flutter_rust_bridge codegen
	cd app/flutter && flutter_rust_bridge_codegen generate

# ── Platform Builds ────────────────────────────────

build-windows: ## Build Windows release
	cd app/flutter && flutter build windows --release

build-linux: ## Build Linux release
	cd app/flutter && flutter build linux --release

build-android: ## Build Android APK
	bash scripts/build_rust.sh android
	cd app/flutter && flutter build apk --release

build-macos: ## Build macOS release
	bash scripts/build_rust.sh macos
	cd app/flutter && flutter build macos --release

build-ios: ## Build iOS (no codesign)
	bash scripts/build_rust.sh ios
	cd app/flutter && flutter build ios --no-codesign

build-web: ## Build Flutter web
	cd app/flutter && flutter build web --release

build-server: ## Build Rust server binary
	bash scripts/build_rust.sh server

# ── Run ────────────────────────────────────────────

run-windows: ## Run on Windows
	cd app/flutter && flutter run -d windows

run-web: ## Run on Chrome
	cd app/flutter && flutter run -d chrome --web-port 3000

run-linux: ## Run on Linux
	cd app/flutter && flutter run -d linux

# ── Release (local convenience) ───────────────────

release-windows: build-windows ## Build Windows installer (requires Inno Setup)
	iscc scripts/inno_setup.iss

release-linux: build-linux ## Build Linux AppImage
	bash scripts/build_appimage.sh $(shell grep 'version:' app/flutter/pubspec.yaml | head -1 | awk '{print $$2}')

release-android: ## Build Android APK + AAB
	bash scripts/build_rust.sh android
	cd app/flutter && flutter build apk --release
	cd app/flutter && flutter build appbundle --release

release-web: build-web ## Zip web build
	cd app/flutter/build/web && zip -r ../../../CrispyTivi-web.zip .

# ── Clean ──────────────────────────────────────────

clean: ## Clean all build artifacts
	cd app/flutter && flutter clean
	cd rust && cargo clean
	@echo "Cleaned Flutter + Rust artifacts"
