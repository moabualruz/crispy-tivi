import 'dart:io';

String crispyConfigHome() {
  final String? explicit = Platform.environment['CRISPY_CONFIG_HOME'];
  if (explicit != null && explicit.trim().isNotEmpty) {
    return explicit.trim();
  }
  final String? xdg = Platform.environment['XDG_CONFIG_HOME'];
  if (xdg != null && xdg.trim().isNotEmpty) {
    return xdg.trim();
  }
  final String? home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return '${home.trim()}/.config';
  }
  return Directory.current.path;
}
