// URL normalization utilities.

/// Normalizes a server URL: trims, adds `http://` if missing, strips
/// trailing slash.
String normalizeServerUrl(String raw) {
  var url = raw.trim();
  final lower = url.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    url = 'http://$url';
  }
  if (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}
