import 'dart:convert';

import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'test_rust_api.dart';

void main() {
  setUpAll(() async {
    await RustShellRuntimeBridge.initializeMock(api: const TestRustApi());
  });

  test('diagnostics runtime bridge returns serialized Rust diagnostics', () async {
    final String json = await const RustShellRuntimeBridge()
        .loadDiagnosticsRuntimeJson();
    final DiagnosticsRuntimeSnapshot snapshot =
        DiagnosticsRuntimeSnapshot.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );

    expect(snapshot.version, '1');
    expect(snapshot.reports, isNotEmpty);
    expect(snapshot.reports.single.streamTitle, 'Crispy One');
  });
}
