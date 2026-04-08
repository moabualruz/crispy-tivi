// Layout helper functions for VOD poster carousels.
//
// Centralizes the responsive breakpoints used by
// RecentlyAddedSection and MoreLikeThisSection so the
// same card-width and section-height values stay in sync.

import '../../../../core/widgets/responsive_layout.dart';

/// Returns the standard VOD poster card width for the given
/// screen width.
///
/// Breakpoints align with [Breakpoints]:
/// - `≥ [Breakpoints.expanded]` (840 px) → 180 px
/// - `≥ [Breakpoints.medium]` (600 px) → 160 px
/// - `< [Breakpoints.medium]` → 140 px
double vodPosterCardWidth(double screenWidth) =>
    screenWidth >= Breakpoints.expanded
        ? 180.0
        : screenWidth >= Breakpoints.medium
        ? 160.0
        : 140.0;

/// Returns the standard VOD carousel section height for the
/// given screen width.
///
/// Breakpoints align with [Breakpoints]:
/// - `≥ [Breakpoints.expanded]` (840 px) → 290 px
/// - `≥ [Breakpoints.medium]` (600 px) → 260 px
/// - `< [Breakpoints.medium]` → 230 px
double vodSectionHeight(double screenWidth) =>
    screenWidth >= Breakpoints.expanded
        ? 290.0
        : screenWidth >= Breakpoints.medium
        ? 260.0
        : 230.0;
