import '../entities/channel.dart';

/// Returns true if [s] starts with a Latin character
/// (Basic Latin U+0041–U+007A or Latin Extended U+00C0–U+024F).
///
/// Non-Latin scripts (Arabic, Cyrillic, CJK, etc.) return false.
/// Whitespace and digits are skipped to find the first significant char.
bool _isLatin(String s) {
  final stripped = s.replaceAll(RegExp(r'[\s\d]'), '');
  if (stripped.isEmpty) return true;
  final cp = stripped.codeUnitAt(0);
  return (cp >= 0x0041 && cp <= 0x007A) || (cp >= 0x00C0 && cp <= 0x024F);
}

/// Returns a sorted, deduplicated list of non-empty group names
/// extracted from [channels].
///
/// Sort order: non-Latin groups (Arabic, etc.) alphabetically first,
/// then Latin groups alphabetically. Case-insensitive within each bucket.
/// This matches the user preference: Arabic groups A–Z, then English A–Z.
List<String> extractSortedGroups(List<Channel> channels) {
  final all =
      channels
          .map((c) => c.group)
          .whereType<String>()
          .where((g) => g.isNotEmpty)
          .toSet();

  final nonLatin =
      all.where((g) => !_isLatin(g)).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final latin =
      all.where((g) => _isLatin(g)).toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return [...nonLatin, ...latin];
}
