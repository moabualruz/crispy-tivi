import 'package:flutter/material.dart';

/// A generated placeholder image showing the first letter(s) of a
/// title on a gradient background.
///
/// Used as the final fallback in the image chain:
/// Original URL → Cached fetched URL → Generated Placeholder.
class GeneratedPlaceholder extends StatelessWidget {
  const GeneratedPlaceholder({
    super.key,
    required this.title,
    this.icon,
    this.fontSize,
    this.iconSize,
  });

  /// Title text — first letter is displayed.
  final String title;

  /// Optional icon to show below the letter.
  final IconData? icon;

  /// Font size for the letter. Auto-calculated if null.
  final double? fontSize;

  /// Icon size. Defaults to 16.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final letter = _extractInitials(title);
    final gradientColors = _gradientForTitle(title);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  letter,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize ?? 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(height: 2),
                  Icon(icon, color: Colors.white70, size: iconSize ?? 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Extracts up to 2 initials from a title.
  static String _extractInitials(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return '?';

    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return trimmed[0].toUpperCase();
  }

  /// Generates a consistent gradient based on the title hash.
  static List<Color> _gradientForTitle(String title) {
    final hash = title.hashCode.abs();
    final hue = (hash % 360).toDouble();

    return [
      HSLColor.fromAHSL(1.0, hue, 0.5, 0.35).toColor(),
      HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.6, 0.25).toColor(),
    ];
  }
}
