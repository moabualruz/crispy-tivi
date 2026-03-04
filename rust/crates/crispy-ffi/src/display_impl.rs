use std::sync::Mutex;
use windows_sys::Win32::Graphics::Gdi::{
    CDS_FULLSCREEN, ChangeDisplaySettingsW, DEVMODEW, DISP_CHANGE_SUCCESSFUL,
    ENUM_CURRENT_SETTINGS, EnumDisplaySettingsW,
};

static ORIGINAL_MODE: Mutex<Option<DEVMODEW>> = Mutex::new(None);

pub fn switch_mode(fps: f64) -> bool {
    unsafe {
        let mut current_mode: DEVMODEW = std::mem::zeroed();
        current_mode.dmSize = std::mem::size_of::<DEVMODEW>() as u16;

        if EnumDisplaySettingsW(std::ptr::null(), ENUM_CURRENT_SETTINGS, &mut current_mode) == 0 {
            return false;
        }

        {
            let mut guard = ORIGINAL_MODE.lock().unwrap();
            if guard.is_none() {
                *guard = Some(current_mode);
            }
        }

        let mut best_mode: Option<DEVMODEW> = None;
        let mut mode_index = 0;
        let mut test_mode: DEVMODEW = std::mem::zeroed();
        test_mode.dmSize = std::mem::size_of::<DEVMODEW>() as u16;

        while EnumDisplaySettingsW(std::ptr::null(), mode_index, &mut test_mode) != 0 {
            if test_mode.dmPelsWidth == current_mode.dmPelsWidth
                && test_mode.dmPelsHeight == current_mode.dmPelsHeight
            {
                let rate = test_mode.dmDisplayFrequency as f64;
                // Match within 1.0Hz or integer multiple
                if (rate - fps).abs() < 1.0 || (rate - (fps * 2.0)).abs() < 1.0 {
                    best_mode = Some(test_mode);
                    break;
                }
            }
            mode_index += 1;
        }

        if let Some(target) = best_mode {
            let current_rate = current_mode.dmDisplayFrequency as f64;
            if (target.dmDisplayFrequency as f64 - current_rate).abs() < 1.0 {
                return true; // Already at the target mode
            }

            // Change mode temporarily
            let res = ChangeDisplaySettingsW(&target, CDS_FULLSCREEN);
            return res == DISP_CHANGE_SUCCESSFUL;
        }
    }
    false
}

pub fn restore_mode() -> bool {
    unsafe {
        let mut guard = ORIGINAL_MODE.lock().unwrap();
        if let Some(orig) = guard.take() {
            let res = ChangeDisplaySettingsW(&orig, CDS_FULLSCREEN);
            return res == DISP_CHANGE_SUCCESSFUL;
        }
    }
    false
}
