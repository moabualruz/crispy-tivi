/// Web implementation of [PlatformInfo].
///
/// Returns safe defaults — all `isX` getters return `false`
/// since the web platform is not a native OS.
library;

import 'platform_info.dart';

/// Factory used by the conditional import.
PlatformInfo createPlatformInfo() => _WebPlatformInfo();

class _WebPlatformInfo implements PlatformInfo {
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
  String get operatingSystem => 'web';
  @override
  String get operatingSystemVersion => '';
}
