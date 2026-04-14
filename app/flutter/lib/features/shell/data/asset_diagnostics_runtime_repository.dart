import 'package:crispy_tivi/features/shell/data/diagnostics_runtime_repository.dart';
import 'package:crispy_tivi/features/shell/domain/diagnostics_runtime.dart';
import 'package:flutter/services.dart';

class AssetDiagnosticsRuntimeRepository extends DiagnosticsRuntimeRepository {
  const AssetDiagnosticsRuntimeRepository();

  static const String assetPath =
      'assets/contracts/asset_diagnostics_runtime.json';

  @override
  Future<DiagnosticsRuntimeSnapshot> load() async {
    final String source = await rootBundle.loadString(assetPath);
    return DiagnosticsRuntimeSnapshot.fromJsonString(source);
  }
}
