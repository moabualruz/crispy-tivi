# Local merge gate. Mirrors the Linux jobs in .github/workflows/ci.yml.
# Same Rust toolchain as RUST_VERSION in ci.yml.
export RUSTUP_TOOLCHAIN := "1.91.1"

ci:
    cd rust && cargo fmt --check -p crispy-core -p crispy-ffi -p crispy-server
    cd rust && cargo clippy --workspace -- -D warnings
    cd rust && cargo test --workspace
    cd app/flutter && flutter pub get
    cd app/flutter && dart format --set-exit-if-changed lib/ test/
    bash scripts/ci/flutter_analyze.sh
    cd app/flutter && dart run tool/check_boundary.dart
    cd app/flutter && flutter test test/config/ test/core/ test/features/
