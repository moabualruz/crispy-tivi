//! Help tips and guided-tour progress service.
//!
//! Tip state and tour progress are stored as KV entries in `db_settings`
//! under keys `"tip::{profile_id}::{tip_id}"` and
//! `"tour::{profile_id}::{tour_id}"` respectively.

use serde::{Deserialize, Serialize};

use super::CrispyService;
use crate::database::DbError;

// ── Constants ─────────────────────────────────────────────────────────────────

/// Maximum number of times a tip may be snoozed before it is auto-dismissed.
const MAX_SNOOZE: u32 = 3;

// ── TipState ─────────────────────────────────────────────────────────────────

/// Lifecycle state of a single contextual tip for a specific profile.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum TipState {
    /// Never shown to this profile.
    #[default]
    NotShown,
    /// Shown at least once; eligible to show again.
    Shown,
    /// Permanently dismissed; never shown again.
    Dismissed,
    /// Snoozed `count` times; reappears next visit until `MAX_SNOOZE`.
    Snoozed { count: u32 },
}

// ── Storage key helpers ───────────────────────────────────────────────────────

fn tip_key(tip_id: &str, profile_id: &str) -> String {
    format!("tip::{profile_id}::{tip_id}")
}

fn tour_key(tour_id: &str, profile_id: &str) -> String {
    format!("tour::{profile_id}::{tour_id}")
}

// ── Service impl ──────────────────────────────────────────────────────────────

impl CrispyService {
    // ── Tip helpers ──────────────────────────────

    /// Return the current state of `tip_id` for `profile_id`.
    pub fn get_tip_state(&self, tip_id: &str, profile_id: &str) -> Result<TipState, DbError> {
        let key = tip_key(tip_id, profile_id);
        match self.get_setting(&key)? {
            Some(json) => Ok(serde_json::from_str(&json).unwrap_or_default()),
            None => Ok(TipState::NotShown),
        }
    }

    fn save_tip_state(
        &self,
        tip_id: &str,
        profile_id: &str,
        state: &TipState,
    ) -> Result<(), DbError> {
        let key = tip_key(tip_id, profile_id);
        let json = serde_json::to_string(state)
            .map_err(|e| DbError::Migration(format!("tip state serialisation: {e}")))?;
        self.set_setting(&key, &json)
    }

    /// Record that the tip has been shown.
    pub fn mark_shown(&self, tip_id: &str, profile_id: &str) -> Result<(), DbError> {
        self.save_tip_state(tip_id, profile_id, &TipState::Shown)
    }

    /// Permanently dismiss a tip — it will never be shown again.
    pub fn mark_dismissed(&self, tip_id: &str, profile_id: &str) -> Result<(), DbError> {
        self.save_tip_state(tip_id, profile_id, &TipState::Dismissed)
    }

    /// Snooze a tip so it reappears next visit.
    ///
    /// After `MAX_SNOOZE` snoozes the tip is auto-dismissed.
    pub fn snooze(&self, tip_id: &str, profile_id: &str) -> Result<(), DbError> {
        let current = self.get_tip_state(tip_id, profile_id)?;
        let new_count = match current {
            TipState::Snoozed { count } => count + 1,
            _ => 1,
        };
        let new_state = if new_count >= MAX_SNOOZE {
            TipState::Dismissed
        } else {
            TipState::Snoozed { count: new_count }
        };
        self.save_tip_state(tip_id, profile_id, &new_state)
    }

    /// Return `true` if the tip should be shown to this profile right now.
    ///
    /// Rules:
    /// - `NotShown` → show.
    /// - `Shown` → show again (repeating tips).
    /// - `Snoozed` → show (it was snoozed, not dismissed).
    /// - `Dismissed` → never show.
    pub fn should_show_tip(&self, tip_id: &str, profile_id: &str) -> Result<bool, DbError> {
        let state = self.get_tip_state(tip_id, profile_id)?;
        Ok(!matches!(state, TipState::Dismissed))
    }

    // ── Guided tour ──────────────────────────────

    /// Return the current step index (0-based) for a guided tour.
    ///
    /// Returns 0 when the tour has never been started.
    pub fn get_tour_progress(&self, tour_id: &str, profile_id: &str) -> Result<u8, DbError> {
        let key = tour_key(tour_id, profile_id);
        match self.get_setting(&key)? {
            Some(s) => Ok(s.parse::<u8>().unwrap_or(0)),
            None => Ok(0),
        }
    }

    /// Advance the tour to the next step.
    pub fn advance_tour(&self, tour_id: &str, profile_id: &str) -> Result<(), DbError> {
        let current = self.get_tour_progress(tour_id, profile_id)?;
        let next = current.saturating_add(1);
        let key = tour_key(tour_id, profile_id);
        self.set_setting(&key, &next.to_string())
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::services::test_helpers::make_service;

    #[test]
    fn test_tip_state_defaults_to_not_shown() {
        let svc = make_service();
        let state = svc.get_tip_state("welcome", "p1").unwrap();
        assert_eq!(state, TipState::NotShown);
    }

    #[test]
    fn test_mark_shown() {
        let svc = make_service();
        svc.mark_shown("tip1", "p1").unwrap();
        assert_eq!(svc.get_tip_state("tip1", "p1").unwrap(), TipState::Shown);
    }

    #[test]
    fn test_mark_dismissed_never_shows_again() {
        let svc = make_service();
        svc.mark_dismissed("tip1", "p1").unwrap();
        assert!(!svc.should_show_tip("tip1", "p1").unwrap());
    }

    #[test]
    fn test_snooze_increments_count() {
        let svc = make_service();
        svc.snooze("tip1", "p1").unwrap();
        assert_eq!(
            svc.get_tip_state("tip1", "p1").unwrap(),
            TipState::Snoozed { count: 1 }
        );
        svc.snooze("tip1", "p1").unwrap();
        assert_eq!(
            svc.get_tip_state("tip1", "p1").unwrap(),
            TipState::Snoozed { count: 2 }
        );
    }

    #[test]
    fn test_snooze_auto_dismisses_after_max() {
        let svc = make_service();
        for _ in 0..MAX_SNOOZE {
            svc.snooze("tip1", "p1").unwrap();
        }
        assert_eq!(
            svc.get_tip_state("tip1", "p1").unwrap(),
            TipState::Dismissed
        );
        assert!(!svc.should_show_tip("tip1", "p1").unwrap());
    }

    #[test]
    fn test_should_show_tip_returns_true_for_snoozed() {
        let svc = make_service();
        svc.snooze("tip1", "p1").unwrap();
        assert!(svc.should_show_tip("tip1", "p1").unwrap());
    }

    #[test]
    fn test_tip_states_are_per_profile() {
        let svc = make_service();
        svc.mark_dismissed("tip1", "p1").unwrap();
        // p2 is unaffected.
        assert!(svc.should_show_tip("tip1", "p2").unwrap());
    }

    #[test]
    fn test_tour_progress_starts_at_zero() {
        let svc = make_service();
        assert_eq!(svc.get_tour_progress("onboarding", "p1").unwrap(), 0);
    }

    #[test]
    fn test_advance_tour_increments() {
        let svc = make_service();
        svc.advance_tour("onboarding", "p1").unwrap();
        assert_eq!(svc.get_tour_progress("onboarding", "p1").unwrap(), 1);
        svc.advance_tour("onboarding", "p1").unwrap();
        assert_eq!(svc.get_tour_progress("onboarding", "p1").unwrap(), 2);
    }

    #[test]
    fn test_tours_are_per_profile() {
        let svc = make_service();
        svc.advance_tour("tour_a", "p1").unwrap();
        assert_eq!(svc.get_tour_progress("tour_a", "p2").unwrap(), 0);
    }
}
