//! Unified 7-tier content rating scale with regional mapping tables.
//!
//! The `ContentRating` enum is the canonical representation used internally.
//! `from_regional` converts region-specific strings to the canonical form;
//! `to_regional` converts back to the region-specific string.
//!
//! Supported rating systems: MPAA, BBFC, FSK, PEGI, ACB, CBFC, EIRIN.

use serde::{Deserialize, Serialize};

// ── ContentRating ─────────────────────────────────────────────────────────────

/// 7-tier canonical content rating.
///
/// Ordered from most permissive to most restrictive.
/// `Unrated` is treated as blocked in children's profiles.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ContentRating {
    /// Suitable for all ages (G / U / FSK 0 / …).
    Everyone,
    /// Parental guidance suggested (PG / 12 / FSK 12 / …).
    ParentalGuidance,
    /// Older children / pre-teens (PG-13 / 12A / FSK 12 / …).
    KidsPlus,
    /// Teenagers (TV-14 / 15 / FSK 16 / PEGI 16 / …).
    Teen,
    /// Mature audiences (R / 18 / FSK 18 / MA 15+ / …).
    Mature,
    /// Adult content (NC-17 / X / R18 / FSK 18 uncut / …).
    Adult,
    /// No rating available — treated as blocked in kids profiles.
    Unrated,
}

impl ContentRating {
    /// Return the region-appropriate display label for this rating.
    ///
    /// Delegates to `to_regional` for recognised systems; falls back to
    /// the canonical variant name for unknown regions.
    ///
    /// # Recognised regions
    /// `"US"` → MPAA, `"GB"` → BBFC, `"DE"` → FSK, `"EU"` → PEGI,
    /// `"AU"` → ACB, `"IN"` → CBFC, `"JP"` → EIRIN.
    /// All others return the variant name (e.g. `"Teen"`).
    pub fn display_label(&self, region: &str) -> &'static str {
        match region.to_ascii_uppercase().as_str() {
            "US" => self.to_regional("mpaa"),
            "GB" => self.to_regional("bbfc"),
            "DE" => self.to_regional("fsk"),
            "EU" => self.to_regional("pegi"),
            "AU" => self.to_regional("acb"),
            "IN" => self.to_regional("cbfc"),
            "JP" => self.to_regional("eirin"),
            _ => match self {
                ContentRating::Everyone => "Everyone",
                ContentRating::ParentalGuidance => "PG",
                ContentRating::KidsPlus => "PG-13",
                ContentRating::Teen => "Teen",
                ContentRating::Mature => "Mature",
                ContentRating::Adult => "Adult",
                ContentRating::Unrated => "Unrated",
            },
        }
    }

    /// Whether this rating is safe for a kids profile (blocks `Unrated`).
    pub fn is_kids_safe(&self) -> bool {
        matches!(
            self,
            ContentRating::Everyone | ContentRating::ParentalGuidance
        )
    }

    /// Convert from a regional rating string.
    ///
    /// `system` is case-insensitive (e.g. `"mpaa"`, `"MPAA"`).
    /// Unknown values map to `Unrated`.
    pub fn from_regional(system: &str, rating: &str) -> ContentRating {
        match system.to_ascii_lowercase().as_str() {
            "mpaa" => Self::from_mpaa(rating),
            "bbfc" => Self::from_bbfc(rating),
            "fsk" => Self::from_fsk(rating),
            "pegi" => Self::from_pegi(rating),
            "acb" => Self::from_acb(rating),
            "cbfc" => Self::from_cbfc(rating),
            "eirin" => Self::from_eirin(rating),
            _ => ContentRating::Unrated,
        }
    }

    /// Convert to a regional rating string.
    ///
    /// Returns `""` for `Unrated` in systems that have no equivalent.
    pub fn to_regional(&self, system: &str) -> &'static str {
        match system.to_ascii_lowercase().as_str() {
            "mpaa" => self.to_mpaa(),
            "bbfc" => self.to_bbfc(),
            "fsk" => self.to_fsk(),
            "pegi" => self.to_pegi(),
            "acb" => self.to_acb(),
            "cbfc" => self.to_cbfc(),
            "eirin" => self.to_eirin(),
            _ => "",
        }
    }
}

// ── MPAA ──────────────────────────────────────────────────────────────────────

impl ContentRating {
    fn from_mpaa(r: &str) -> Self {
        match r.trim().to_ascii_uppercase().as_str() {
            "G" => ContentRating::Everyone,
            "PG" => ContentRating::ParentalGuidance,
            "PG-13" => ContentRating::KidsPlus,
            "R" => ContentRating::Mature,
            "NC-17" => ContentRating::Adult,
            "TV-G" => ContentRating::Everyone,
            "TV-PG" => ContentRating::ParentalGuidance,
            "TV-14" => ContentRating::Teen,
            "TV-MA" => ContentRating::Mature,
            _ => ContentRating::Unrated,
        }
    }

    fn to_mpaa(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "G",
            ContentRating::ParentalGuidance => "PG",
            ContentRating::KidsPlus => "PG-13",
            ContentRating::Teen => "TV-14",
            ContentRating::Mature => "R",
            ContentRating::Adult => "NC-17",
            ContentRating::Unrated => "NR",
        }
    }
}

// ── BBFC ──────────────────────────────────────────────────────────────────────

impl ContentRating {
    fn from_bbfc(r: &str) -> Self {
        match r.trim().to_ascii_uppercase().as_str() {
            "U" => ContentRating::Everyone,
            "PG" => ContentRating::ParentalGuidance,
            "12" | "12A" => ContentRating::KidsPlus,
            "15" => ContentRating::Teen,
            "18" => ContentRating::Mature,
            "R18" => ContentRating::Adult,
            _ => ContentRating::Unrated,
        }
    }

    fn to_bbfc(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "U",
            ContentRating::ParentalGuidance => "PG",
            ContentRating::KidsPlus => "12A",
            ContentRating::Teen => "15",
            ContentRating::Mature => "18",
            ContentRating::Adult => "R18",
            ContentRating::Unrated => "",
        }
    }
}

// ── FSK (Germany) ─────────────────────────────────────────────────────────────

impl ContentRating {
    fn from_fsk(r: &str) -> Self {
        match r.trim() {
            "0" | "FSK 0" => ContentRating::Everyone,
            "6" | "FSK 6" => ContentRating::ParentalGuidance,
            "12" | "FSK 12" => ContentRating::KidsPlus,
            "16" | "FSK 16" => ContentRating::Teen,
            "18" | "FSK 18" => ContentRating::Mature,
            "18+" | "FSK 18+" => ContentRating::Adult,
            _ => ContentRating::Unrated,
        }
    }

    fn to_fsk(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "FSK 0",
            ContentRating::ParentalGuidance => "FSK 6",
            ContentRating::KidsPlus => "FSK 12",
            ContentRating::Teen => "FSK 16",
            ContentRating::Mature => "FSK 18",
            ContentRating::Adult => "FSK 18+",
            ContentRating::Unrated => "",
        }
    }
}

// ── PEGI (Europe) ─────────────────────────────────────────────────────────────

impl ContentRating {
    fn from_pegi(r: &str) -> Self {
        match r.trim() {
            "3" | "PEGI 3" => ContentRating::Everyone,
            "7" | "PEGI 7" => ContentRating::ParentalGuidance,
            "12" | "PEGI 12" => ContentRating::KidsPlus,
            "16" | "PEGI 16" => ContentRating::Teen,
            "18" | "PEGI 18" => ContentRating::Mature,
            _ => ContentRating::Unrated,
        }
    }

    fn to_pegi(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "PEGI 3",
            ContentRating::ParentalGuidance => "PEGI 7",
            ContentRating::KidsPlus => "PEGI 12",
            ContentRating::Teen => "PEGI 16",
            ContentRating::Mature | ContentRating::Adult => "PEGI 18",
            ContentRating::Unrated => "",
        }
    }
}

// ── ACB (Australia) ───────────────────────────────────────────────────────────

impl ContentRating {
    fn from_acb(r: &str) -> Self {
        match r.trim().to_ascii_uppercase().as_str() {
            "G" | "P" => ContentRating::Everyone,
            "PG" => ContentRating::ParentalGuidance,
            "M" => ContentRating::KidsPlus,
            "MA" | "MA 15+" | "MA15+" => ContentRating::Mature,
            "R" | "R 18+" | "R18+" => ContentRating::Adult,
            "X" | "X 18+" | "X18+" => ContentRating::Adult,
            _ => ContentRating::Unrated,
        }
    }

    fn to_acb(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "G",
            ContentRating::ParentalGuidance => "PG",
            ContentRating::KidsPlus | ContentRating::Teen => "M",
            ContentRating::Mature => "MA 15+",
            ContentRating::Adult => "R 18+",
            ContentRating::Unrated => "",
        }
    }
}

// ── CBFC (India) ──────────────────────────────────────────────────────────────

impl ContentRating {
    fn from_cbfc(r: &str) -> Self {
        match r.trim().to_ascii_uppercase().as_str() {
            "U" => ContentRating::Everyone,
            "U/A" | "UA" | "U/A 7+" => ContentRating::ParentalGuidance,
            "U/A 13+" => ContentRating::KidsPlus,
            "U/A 16+" => ContentRating::Teen,
            "A" => ContentRating::Mature,
            "S" => ContentRating::Adult,
            _ => ContentRating::Unrated,
        }
    }

    fn to_cbfc(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "U",
            ContentRating::ParentalGuidance => "U/A 7+",
            ContentRating::KidsPlus => "U/A 13+",
            ContentRating::Teen => "U/A 16+",
            ContentRating::Mature => "A",
            ContentRating::Adult => "S",
            ContentRating::Unrated => "",
        }
    }
}

// ── EIRIN (Japan) ─────────────────────────────────────────────────────────────

impl ContentRating {
    fn from_eirin(r: &str) -> Self {
        match r.trim().to_ascii_uppercase().as_str() {
            "G" => ContentRating::Everyone,
            "PG12" | "PG-12" => ContentRating::ParentalGuidance,
            "R15+" | "R-15" => ContentRating::Teen,
            "R18+" | "R-18" => ContentRating::Adult,
            _ => ContentRating::Unrated,
        }
    }

    fn to_eirin(&self) -> &'static str {
        match self {
            ContentRating::Everyone => "G",
            ContentRating::ParentalGuidance | ContentRating::KidsPlus => "PG12",
            ContentRating::Teen => "R15+",
            ContentRating::Mature | ContentRating::Adult => "R18+",
            ContentRating::Unrated => "",
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // Helper: round-trip through a system
    fn roundtrip(system: &str, cr: ContentRating) -> ContentRating {
        let regional = cr.to_regional(system);
        ContentRating::from_regional(system, regional)
    }

    #[test]
    fn test_mpaa_all_roundtrip() {
        for cr in [
            ContentRating::Everyone,
            ContentRating::ParentalGuidance,
            ContentRating::KidsPlus,
            ContentRating::Teen,
            ContentRating::Mature,
            ContentRating::Adult,
        ] {
            assert_eq!(
                roundtrip("mpaa", cr),
                cr,
                "MPAA roundtrip failed for {cr:?}"
            );
        }
    }

    #[test]
    fn test_bbfc_all_roundtrip() {
        for cr in [
            ContentRating::Everyone,
            ContentRating::ParentalGuidance,
            ContentRating::KidsPlus,
            ContentRating::Teen,
            ContentRating::Mature,
            ContentRating::Adult,
        ] {
            assert_eq!(
                roundtrip("bbfc", cr),
                cr,
                "BBFC roundtrip failed for {cr:?}"
            );
        }
    }

    #[test]
    fn test_fsk_all_roundtrip() {
        for cr in [
            ContentRating::Everyone,
            ContentRating::ParentalGuidance,
            ContentRating::KidsPlus,
            ContentRating::Teen,
            ContentRating::Mature,
            ContentRating::Adult,
        ] {
            assert_eq!(roundtrip("fsk", cr), cr, "FSK roundtrip failed for {cr:?}");
        }
    }

    #[test]
    fn test_pegi_adult_maps_to_pegi18() {
        // PEGI has no Adult tier; both Mature and Adult → PEGI 18
        assert_eq!(
            ContentRating::from_regional("pegi", "PEGI 18"),
            ContentRating::Mature
        );
    }

    #[test]
    fn test_acb_roundtrip_non_adult() {
        for cr in [ContentRating::Everyone, ContentRating::ParentalGuidance] {
            assert_eq!(roundtrip("acb", cr), cr, "ACB roundtrip failed for {cr:?}");
        }
    }

    #[test]
    fn test_cbfc_roundtrip() {
        for cr in [
            ContentRating::Everyone,
            ContentRating::ParentalGuidance,
            ContentRating::KidsPlus,
            ContentRating::Teen,
            ContentRating::Mature,
            ContentRating::Adult,
        ] {
            assert_eq!(
                roundtrip("cbfc", cr),
                cr,
                "CBFC roundtrip failed for {cr:?}"
            );
        }
    }

    #[test]
    fn test_eirin_roundtrip() {
        for cr in [
            ContentRating::Everyone,
            ContentRating::ParentalGuidance,
            ContentRating::Teen,
            ContentRating::Adult,
        ] {
            assert_eq!(
                roundtrip("eirin", cr),
                cr,
                "EIRIN roundtrip failed for {cr:?}"
            );
        }
    }

    #[test]
    fn test_unknown_system_returns_unrated() {
        assert_eq!(
            ContentRating::from_regional("unknown_system", "X"),
            ContentRating::Unrated
        );
    }

    #[test]
    fn test_unknown_rating_in_known_system_returns_unrated() {
        assert_eq!(
            ContentRating::from_regional("mpaa", "ZZ"),
            ContentRating::Unrated
        );
    }

    #[test]
    fn test_unrated_is_not_kids_safe() {
        assert!(!ContentRating::Unrated.is_kids_safe());
    }

    #[test]
    fn test_everyone_is_kids_safe() {
        assert!(ContentRating::Everyone.is_kids_safe());
    }

    #[test]
    fn test_teen_is_not_kids_safe() {
        assert!(!ContentRating::Teen.is_kids_safe());
    }

    #[test]
    fn test_system_case_insensitive() {
        let a = ContentRating::from_regional("MPAA", "G");
        let b = ContentRating::from_regional("mpaa", "G");
        assert_eq!(a, b);
    }

    #[test]
    fn test_ordering() {
        assert!(ContentRating::Everyone < ContentRating::Adult);
        assert!(ContentRating::Teen < ContentRating::Mature);
    }
}
