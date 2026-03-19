//! Responsive layout tier system for CrispyTivi.
//!
//! Defines four layout breakpoints matching the spec:
//!
//! | Tier     | Width         | Target              |
//! |----------|---------------|---------------------|
//! | Compact  | < 600 px      | Phone portrait      |
//! | Medium   | 600 – 1023 px | Phone landscape / tablet portrait |
//! | Expanded | 1024 – 1439px | Tablet landscape / desktop small  |
//! | Wide     | ≥ 1440 px     | Desktop / TV        |
//!
//! The [`LayoutTier`] enum is computed from a pixel width and drives
//! component configuration (grid columns, panel visibility, font scale,
//! OSD layout, etc.).

// ── Layout tier ──────────────────────────────────────────────────────────────

/// Responsive layout tier derived from the window/viewport width.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub(crate) enum LayoutTier {
    /// < 600 px — phone portrait.  Single-column, full-width cards.
    Compact,
    /// 600 – 1023 px — phone landscape / tablet portrait.
    /// Two-column grid, side-by-side panels allowed.
    Medium,
    /// 1024 – 1439 px — tablet landscape / small desktop.
    /// Full navigation visible, three-column grid, EPG PiP enabled.
    Expanded,
    /// ≥ 1440 px — desktop / TV / large monitor.
    /// Maximum density: multi-column grid, persistent sidebar, EPG full grid.
    Wide,
}

impl LayoutTier {
    // ── Breakpoint constants ──────────────────────────────────────────────

    /// Upper exclusive bound for [`LayoutTier::Compact`].
    pub(crate) const COMPACT_MAX: u32 = 600;
    /// Upper exclusive bound for [`LayoutTier::Medium`].
    pub(crate) const MEDIUM_MAX: u32 = 1024;
    /// Upper exclusive bound for [`LayoutTier::Expanded`].
    pub(crate) const EXPANDED_MAX: u32 = 1440;

    // ── Constructor ───────────────────────────────────────────────────────

    /// Derive the layout tier from a logical pixel width.
    ///
    /// ```
    /// use crispy_ui::layout::LayoutTier;
    ///
    /// assert_eq!(LayoutTier::from_width(480),  LayoutTier::Compact);
    /// assert_eq!(LayoutTier::from_width(600),  LayoutTier::Medium);
    /// assert_eq!(LayoutTier::from_width(1024), LayoutTier::Expanded);
    /// assert_eq!(LayoutTier::from_width(1440), LayoutTier::Wide);
    /// ```
    pub(crate) fn from_width(width_px: u32) -> Self {
        if width_px < Self::COMPACT_MAX {
            Self::Compact
        } else if width_px < Self::MEDIUM_MAX {
            Self::Medium
        } else if width_px < Self::EXPANDED_MAX {
            Self::Expanded
        } else {
            Self::Wide
        }
    }

    // ── Grid columns ──────────────────────────────────────────────────────

    /// Number of content-card columns for this tier.
    ///
    /// Used for channel/VOD grid layouts.
    pub(crate) fn grid_columns(&self) -> u32 {
        match self {
            Self::Compact => 1,
            Self::Medium => 2,
            Self::Expanded => 3,
            Self::Wide => 4,
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────

    /// Whether the top navigation bar labels are visible
    /// (as opposed to icon-only compact mode).
    pub(crate) fn nav_labels_visible(&self) -> bool {
        matches!(self, Self::Expanded | Self::Wide)
    }

    /// Whether a persistent side panel (e.g. category filter) should be shown.
    pub(crate) fn side_panel_visible(&self) -> bool {
        matches!(self, Self::Expanded | Self::Wide)
    }

    // ── EPG ───────────────────────────────────────────────────────────────

    /// Whether the EPG Picture-in-Picture player is displayed alongside the
    /// guide grid (requires enough horizontal space).
    pub(crate) fn epg_pip_enabled(&self) -> bool {
        matches!(self, Self::Expanded | Self::Wide)
    }

    /// EPG grid width as a fraction of the total viewport width (0.0 – 1.0).
    ///
    /// On `Wide`, the EPG grid occupies 70 % and the PiP player 25 %,
    /// matching the design spec.  Compact/Medium use the full width.
    pub(crate) fn epg_grid_fraction(&self) -> f32 {
        match self {
            Self::Compact | Self::Medium => 1.0,
            Self::Expanded => 0.75,
            Self::Wide => 0.70,
        }
    }

    // ── Typography scale ──────────────────────────────────────────────────

    /// Relative font scale factor applied to base sizes.
    ///
    /// `1.0` = unchanged design-token size. Values below 1 shrink text
    /// slightly on small screens to prevent overflow.
    pub(crate) fn font_scale(&self) -> f32 {
        match self {
            Self::Compact => 0.85,
            Self::Medium => 0.92,
            Self::Expanded => 1.0,
            Self::Wide => 1.0,
        }
    }

    // ── Introspection ─────────────────────────────────────────────────────

    /// Returns `true` for phone-class viewports.
    pub(crate) fn is_phone(&self) -> bool {
        matches!(self, Self::Compact | Self::Medium)
    }

    /// Returns `true` for tablet-or-larger viewports.
    pub(crate) fn is_tablet_or_larger(&self) -> bool {
        matches!(self, Self::Expanded | Self::Wide)
    }

    /// Human-readable name for diagnostics / logging.
    pub(crate) fn name(&self) -> &'static str {
        match self {
            Self::Compact => "Compact",
            Self::Medium => "Medium",
            Self::Expanded => "Expanded",
            Self::Wide => "Wide",
        }
    }
}

impl std::fmt::Display for LayoutTier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.name())
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── from_width ────────────────────────────────────────────────────────

    #[test]
    fn test_from_width_returns_compact_when_below_600() {
        assert_eq!(LayoutTier::from_width(0), LayoutTier::Compact);
        assert_eq!(LayoutTier::from_width(320), LayoutTier::Compact);
        assert_eq!(LayoutTier::from_width(599), LayoutTier::Compact);
    }

    #[test]
    fn test_from_width_returns_medium_when_600_to_1023() {
        assert_eq!(LayoutTier::from_width(600), LayoutTier::Medium);
        assert_eq!(LayoutTier::from_width(768), LayoutTier::Medium);
        assert_eq!(LayoutTier::from_width(1023), LayoutTier::Medium);
    }

    #[test]
    fn test_from_width_returns_expanded_when_1024_to_1439() {
        assert_eq!(LayoutTier::from_width(1024), LayoutTier::Expanded);
        assert_eq!(LayoutTier::from_width(1280), LayoutTier::Expanded);
        assert_eq!(LayoutTier::from_width(1439), LayoutTier::Expanded);
    }

    #[test]
    fn test_from_width_returns_wide_when_1440_or_more() {
        assert_eq!(LayoutTier::from_width(1440), LayoutTier::Wide);
        assert_eq!(LayoutTier::from_width(1920), LayoutTier::Wide);
        assert_eq!(LayoutTier::from_width(3840), LayoutTier::Wide);
    }

    // ── Exact boundary values ─────────────────────────────────────────────

    #[test]
    fn test_from_width_boundary_compact_medium() {
        assert_eq!(LayoutTier::from_width(599), LayoutTier::Compact);
        assert_eq!(LayoutTier::from_width(600), LayoutTier::Medium);
    }

    #[test]
    fn test_from_width_boundary_medium_expanded() {
        assert_eq!(LayoutTier::from_width(1023), LayoutTier::Medium);
        assert_eq!(LayoutTier::from_width(1024), LayoutTier::Expanded);
    }

    #[test]
    fn test_from_width_boundary_expanded_wide() {
        assert_eq!(LayoutTier::from_width(1439), LayoutTier::Expanded);
        assert_eq!(LayoutTier::from_width(1440), LayoutTier::Wide);
    }

    // ── grid_columns ─────────────────────────────────────────────────────

    #[test]
    fn test_grid_columns_increases_with_tier() {
        assert_eq!(LayoutTier::Compact.grid_columns(), 1);
        assert_eq!(LayoutTier::Medium.grid_columns(), 2);
        assert_eq!(LayoutTier::Expanded.grid_columns(), 3);
        assert_eq!(LayoutTier::Wide.grid_columns(), 4);
    }

    // ── nav_labels_visible ────────────────────────────────────────────────

    #[test]
    fn test_nav_labels_hidden_on_small_tiers() {
        assert!(!LayoutTier::Compact.nav_labels_visible());
        assert!(!LayoutTier::Medium.nav_labels_visible());
    }

    #[test]
    fn test_nav_labels_visible_on_large_tiers() {
        assert!(LayoutTier::Expanded.nav_labels_visible());
        assert!(LayoutTier::Wide.nav_labels_visible());
    }

    // ── side_panel_visible ────────────────────────────────────────────────

    #[test]
    fn test_side_panel_hidden_on_phone_tiers() {
        assert!(!LayoutTier::Compact.side_panel_visible());
        assert!(!LayoutTier::Medium.side_panel_visible());
    }

    #[test]
    fn test_side_panel_visible_on_tablet_and_larger() {
        assert!(LayoutTier::Expanded.side_panel_visible());
        assert!(LayoutTier::Wide.side_panel_visible());
    }

    // ── epg_pip_enabled ───────────────────────────────────────────────────

    #[test]
    fn test_epg_pip_disabled_on_small_tiers() {
        assert!(!LayoutTier::Compact.epg_pip_enabled());
        assert!(!LayoutTier::Medium.epg_pip_enabled());
    }

    #[test]
    fn test_epg_pip_enabled_on_large_tiers() {
        assert!(LayoutTier::Expanded.epg_pip_enabled());
        assert!(LayoutTier::Wide.epg_pip_enabled());
    }

    // ── epg_grid_fraction ─────────────────────────────────────────────────

    #[test]
    fn test_epg_grid_fraction_full_on_small_tiers() {
        assert!((LayoutTier::Compact.epg_grid_fraction() - 1.0).abs() < f32::EPSILON);
        assert!((LayoutTier::Medium.epg_grid_fraction() - 1.0).abs() < f32::EPSILON);
    }

    #[test]
    fn test_epg_grid_fraction_reduced_on_large_tiers() {
        assert!(LayoutTier::Expanded.epg_grid_fraction() < 1.0);
        assert!(LayoutTier::Wide.epg_grid_fraction() < 1.0);
    }

    #[test]
    fn test_epg_grid_fraction_wide_matches_spec() {
        // Design spec: 70% grid + 25% PiP on Wide tier.
        assert!((LayoutTier::Wide.epg_grid_fraction() - 0.70).abs() < f32::EPSILON);
    }

    // ── font_scale ────────────────────────────────────────────────────────

    #[test]
    fn test_font_scale_compact_is_smaller() {
        assert!(LayoutTier::Compact.font_scale() < 1.0);
    }

    #[test]
    fn test_font_scale_expanded_and_wide_are_unity() {
        assert!((LayoutTier::Expanded.font_scale() - 1.0).abs() < f32::EPSILON);
        assert!((LayoutTier::Wide.font_scale() - 1.0).abs() < f32::EPSILON);
    }

    // ── is_phone / is_tablet_or_larger ───────────────────────────────────

    #[test]
    fn test_is_phone_true_for_compact_and_medium() {
        assert!(LayoutTier::Compact.is_phone());
        assert!(LayoutTier::Medium.is_phone());
        assert!(!LayoutTier::Expanded.is_phone());
        assert!(!LayoutTier::Wide.is_phone());
    }

    #[test]
    fn test_is_tablet_or_larger_true_for_expanded_and_wide() {
        assert!(!LayoutTier::Compact.is_tablet_or_larger());
        assert!(!LayoutTier::Medium.is_tablet_or_larger());
        assert!(LayoutTier::Expanded.is_tablet_or_larger());
        assert!(LayoutTier::Wide.is_tablet_or_larger());
    }

    // ── name / Display ────────────────────────────────────────────────────

    #[test]
    fn test_name_returns_expected_strings() {
        assert_eq!(LayoutTier::Compact.name(), "Compact");
        assert_eq!(LayoutTier::Medium.name(), "Medium");
        assert_eq!(LayoutTier::Expanded.name(), "Expanded");
        assert_eq!(LayoutTier::Wide.name(), "Wide");
    }

    #[test]
    fn test_display_matches_name() {
        for tier in [
            LayoutTier::Compact,
            LayoutTier::Medium,
            LayoutTier::Expanded,
            LayoutTier::Wide,
        ] {
            assert_eq!(tier.to_string(), tier.name());
        }
    }

    // ── Ordering ──────────────────────────────────────────────────────────

    #[test]
    fn test_tiers_are_ordered_by_size() {
        assert!(LayoutTier::Compact < LayoutTier::Medium);
        assert!(LayoutTier::Medium < LayoutTier::Expanded);
        assert!(LayoutTier::Expanded < LayoutTier::Wide);
    }
}
