import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';

abstract class DiagnosticsRuntimeRepository {
  const DiagnosticsRuntimeRepository();

  Future<DiagnosticsRuntimeSnapshot> load();
}
