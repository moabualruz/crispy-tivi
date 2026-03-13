/// Stub implementation — should never be reached at runtime.
///
/// The conditional import in `platform_info.dart` always resolves
/// to either `_io` or `_web`. This file exists only to satisfy
/// the Dart analyzer's requirement for a default import target.
library;

import 'platform_info.dart';

/// Factory used by the conditional import.
PlatformInfo createPlatformInfo() => _StubPlatformInfo();

class _StubPlatformInfo implements PlatformInfo {
  @override
  bool get isWindows => false;
  @override
  bool get isAndroid => false;
  @override
  bool get isIOS => false;
  @override
  bool get isMacOS => false;
  @override
  bool get isLinux => false;
  @override
  bool get isFuchsia => false;
  @override
  String get operatingSystem => 'unknown';
  @override
  String get operatingSystemVersion => '';
}
