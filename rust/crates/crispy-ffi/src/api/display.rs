use anyhow::Result;

/// Attempt to switch the Windows display refresh rate to best match the given FPS.
/// Returns true if successful or if no change was needed. On non-Windows platforms, returns false.
pub fn afr_switch_mode(fps: f64) -> Result<bool> {
    #[cfg(windows)]
    {
        Ok(crate::display_impl::switch_mode(fps))
    }
    #[cfg(not(windows))]
    {
        let _ = fps;
        Ok(false)
    }
}

/// Restore the original display mode if it was changed.
pub fn afr_restore_mode() -> Result<bool> {
    #[cfg(windows)]
    {
        Ok(crate::display_impl::restore_mode())
    }
    #[cfg(not(windows))]
    {
        Ok(false)
    }
}
