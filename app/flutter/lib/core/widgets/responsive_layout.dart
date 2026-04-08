import 'package:flutter/material.dart';

import '../utils/device_form_factor.dart';
import 'ui_auto_scale.dart';

/// Breakpoints for adaptive layout decisions.
///
/// All layout decisions flow through these constants
/// and the [ResponsiveLayout] widget — never hardcode
/// breakpoint checks in feature code.
abstract final class Breakpoints {
  /// Compact: phones (portrait).
  static const double compact = 0;

  /// Medium: tablets, large phones (landscape).
  static const double medium = 600;

  /// Expanded: desktops, laptops, landscape tablets.
  static const double expanded = 840;

  /// Large: TVs, ultra-wide monitors.
  static const double large = 1200;
}

/// Determines current layout class from screen width.
enum LayoutClass {
  /// Phones (< 600dp).
  compact,

  /// Tablets / large phones (600–839dp).
  medium,

  /// Desktop / laptop (840–1199dp).
  expanded,

  /// TV / ultra-wide (≥ 1200dp).
  large;

  static LayoutClass fromWidth(double width) {
    if (width >= Breakpoints.large) return LayoutClass.large;
    if (width >= Breakpoints.expanded) {
      return LayoutClass.expanded;
    }
    if (width >= Breakpoints.medium) return LayoutClass.medium;
    return LayoutClass.compact;
  }

  /// True for layouts that use side navigation.
  bool get usesSideNav =>
      this == LayoutClass.expanded || this == LayoutClass.large;

  /// True for TV layouts needing D-pad focus management.
  /// Uses actual Android TV detection (leanback) in addition to the
  /// width heuristic, so TVs at unusual resolutions still get
  /// D-pad focus and overscan padding.
  bool get isTvLayout =>
      this == LayoutClass.large || DeviceFormFactorService.current.isTV;
}

/// Adaptive layout wrapper.
///
/// - **Mobile (compact)**: Bottom navigation.
/// - **Tablet (medium)**: Bottom navigation (wider).
/// - **Desktop (expanded)**: Collapsible side rail.
/// - **TV (large)**: Side rail with focus management.
///
/// Usage:
/// ```dart
/// ResponsiveLayout(
///   compactBody: MobileHomePage(),
///   expandedBody: DesktopHomePage(),
/// )
/// ```
///
/// Respects `SafeArea` and TV overscan padding.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.compactBody,
    this.mediumBody,
    this.expandedBody,
    this.largeBody,
    super.key,
  });

  /// UI for phones (< 600dp). Always required.
  final Widget compactBody;

  /// UI for tablets (600–839dp). Falls back to [compactBody].
  final Widget? mediumBody;

  /// UI for desktops (840–1199dp). Falls back to [mediumBody].
  final Widget? expandedBody;

  /// UI for TVs (≥ 1200dp). Falls back to [expandedBody].
  final Widget? largeBody;

  /// Standard TV overscan safe-area padding (5% of 1080p = 54px ÷ 2 sides).
  ///
  /// Applies to large-layout screens to prevent content from being obscured
  /// by TV bezel/overscan on older displays. Value: 27dp on all sides.
  static const kTvOverscanPadding = EdgeInsets.all(27.0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Unscale width so breakpoints evaluate against original
          // logical dimensions, not the auto-scaled ones.
          final autoScale = UiAutoScale.of(context);
          final layoutClass = LayoutClass.fromWidth(
            constraints.maxWidth * autoScale,
          );

          final body = switch (layoutClass) {
            LayoutClass.large =>
              largeBody ?? expandedBody ?? mediumBody ?? compactBody,
            LayoutClass.expanded => expandedBody ?? mediumBody ?? compactBody,
            LayoutClass.medium => mediumBody ?? compactBody,
            LayoutClass.compact => compactBody,
          };

          // Apply TV overscan padding on large screens.
          if (layoutClass.isTvLayout) {
            return Padding(padding: kTvOverscanPadding, child: body);
          }

          return body;
        },
      ),
    );
  }
}

/// Extension to easily query the current layout class.
extension LayoutContext on BuildContext {
  LayoutClass get layoutClass {
    final width = MediaQuery.sizeOf(this).width;
    final autoScale = UiAutoScale.of(this);
    return LayoutClass.fromWidth(width * autoScale);
  }

  /// True when the device is a phone (shortest side < 600dp).
  /// Independent of current orientation. Always false on web.
  bool get isPhoneFormFactor =>
      MediaQuery.sizeOf(this).shortestSide < Breakpoints.medium;

  bool get isCompact => layoutClass == LayoutClass.compact;
  bool get isMedium => layoutClass == LayoutClass.medium;
  bool get isExpanded => layoutClass == LayoutClass.expanded;
  bool get isLarge => layoutClass == LayoutClass.large;
  bool get usesSideNav => layoutClass.usesSideNav;
}
