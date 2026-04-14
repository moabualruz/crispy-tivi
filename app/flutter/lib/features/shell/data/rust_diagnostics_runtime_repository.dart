import 'package:crispy_tivi/features/shell/data/diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/data/rust_shell_runtime_bridge.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';

class RustDiagnosticsRuntimeRepository extends DiagnosticsRuntimeRepository {
  RustDiagnosticsRuntimeRepository({ShellRuntimeBridge? shellRuntimeBridge})
    : shellRuntimeBridge = shellRuntimeBridge ?? createShellRuntimeBridge();

  final ShellRuntimeBridge shellRuntimeBridge;

  @override
  Future<DiagnosticsRuntimeSnapshot> load() async {
    final String source = await shellRuntimeBridge.loadDiagnosticsRuntimeJson();
    return DiagnosticsRuntimeSnapshot.fromJsonString(source);
  }
}
