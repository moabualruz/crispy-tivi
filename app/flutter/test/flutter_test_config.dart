import 'dart:io';

import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';

import 'features/shell/test_rust_api.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  if (Platform.environment['CRISPY_REAL_RUST_TEST'] != '1') {
    await RustShellRuntimeBridge.initializeMock(api: const TestRustApi());
  }
  await testMain();
}
