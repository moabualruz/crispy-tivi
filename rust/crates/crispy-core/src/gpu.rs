//! GPU detection for video upscaling tier selection.
//!
//! Detects the primary GPU on the current system and
//! returns metadata used to select the best video
//! super-resolution (VSR) pipeline.
//!
//! Platform-specific:
//! - Windows: DXGI `EnumAdapters1` via the `windows` crate
//! - Linux: `/sys/class/drm/card0/device/vendor`
//! - macOS: placeholder returning Apple + MetalFxSpatial
//! - Other: returns `GpuInfo::default()` (Unknown)

use serde::{Deserialize, Serialize};

/// Detected GPU information for VSR tier selection.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuInfo {
    /// GPU vendor (NVIDIA, AMD, Intel, etc.).
    pub vendor: GpuVendor,
    /// Human-readable adapter name.
    pub name: String,
    /// Dedicated video memory in megabytes.
    pub vram_mb: Option<u64>,
    /// Whether hardware-accelerated VSR is available.
    pub supports_hw_vsr: bool,
    /// Best VSR method for this GPU.
    pub vsr_method: VsrMethod,
}

/// GPU vendor identification.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum GpuVendor {
    Nvidia,
    Amd,
    Intel,
    Apple,
    Qualcomm,
    Arm,
    Unknown,
}

/// Video super-resolution method.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum VsrMethod {
    /// NVIDIA RTX Video Super Resolution via D3D11.
    D3d11Nvidia,
    /// Intel XeSS / driver VSR via D3D11.
    D3d11Intel,
    /// AMD Radeon Super Resolution (driver-level).
    AmdDriverRsr,
    /// Apple MetalFX Spatial Scaler.
    MetalFxSpatial,
    /// WebGPU compute-shader CNN upscaler.
    WebGpuCnn,
    /// WebGL FSR shader fallback.
    WebGlFsr,
    /// Software AMD FidelityFX FSR 1.0.
    SoftwareFsr,
    /// Software Lanczos resampling.
    SoftwareLanczos,
    /// NVIDIA RTX Video SDK (direct AI upscaling).
    RtxVideoSdk,
    /// Apple Core ML super resolution.
    CoreMlSuperRes,
    /// Qualcomm GSR (Game Super Resolution) shader.
    QualcommGsr,
    /// No upscaling available.
    None,
}

impl Default for GpuInfo {
    fn default() -> Self {
        Self {
            vendor: GpuVendor::Unknown,
            name: "Unknown".to_string(),
            vram_mb: Option::None,
            supports_hw_vsr: false,
            vsr_method: VsrMethod::None,
        }
    }
}

/// Detect the primary GPU on the current system.
///
/// Returns a [`GpuInfo`] with vendor, name, VRAM, and
/// the recommended VSR method. Falls back to
/// `GpuInfo::default()` on unsupported platforms.
pub fn detect_gpu() -> GpuInfo {
    #[cfg(target_os = "windows")]
    {
        detect_gpu_windows()
    }

    #[cfg(target_os = "linux")]
    {
        detect_gpu_linux()
    }

    #[cfg(target_os = "macos")]
    {
        detect_gpu_macos()
    }

    #[cfg(not(any(target_os = "windows", target_os = "linux", target_os = "macos")))]
    {
        GpuInfo::default()
    }
}

// ── Windows DXGI detection ──────────────────────────

#[cfg(target_os = "windows")]
fn detect_gpu_windows() -> GpuInfo {
    use windows::Win32::Graphics::Dxgi::{CreateDXGIFactory1, IDXGIFactory1};

    // Try to create a DXGI factory.
    let factory: IDXGIFactory1 = match unsafe { CreateDXGIFactory1() } {
        Ok(f) => f,
        Err(_) => return GpuInfo::default(),
    };

    // Enumerate adapters, skip software renderer.
    let mut best: Option<GpuInfo> = Option::None;

    for i in 0..16u32 {
        let adapter = match unsafe { factory.EnumAdapters1(i) } {
            Ok(a) => a,
            Err(_) => break,
        };

        let desc = match unsafe { adapter.GetDesc1() } {
            Ok(d) => d,
            Err(_) => continue,
        };

        // Skip the Microsoft Basic Render Driver.
        if (desc.Flags & 0x2) != 0 {
            // DXGI_ADAPTER_FLAG_SOFTWARE = 0x2
            continue;
        }

        let vendor_id = desc.VendorId;
        let vendor = match vendor_id {
            0x10DE => GpuVendor::Nvidia,
            0x1002 => GpuVendor::Amd,
            0x8086 => GpuVendor::Intel,
            _ => GpuVendor::Unknown,
        };

        // Decode the adapter description (UTF-16).
        let name_raw = &desc.Description;
        let name_len = name_raw
            .iter()
            .position(|&c| c == 0)
            .unwrap_or(name_raw.len());
        let name = String::from_utf16_lossy(&name_raw[..name_len]);

        let vram_mb = desc.DedicatedVideoMemory as u64 / (1024 * 1024);

        let (supports_hw, method) = classify_vsr(&vendor, &name);

        let info = GpuInfo {
            vendor,
            name,
            vram_mb: Some(vram_mb),
            supports_hw_vsr: supports_hw,
            vsr_method: method,
        };

        // Prefer the first discrete GPU found.
        if best.is_none() {
            best = Some(info);
        }
    }

    best.unwrap_or_default()
}

/// Classify the best VSR method from vendor + name.
#[cfg(target_os = "windows")]
fn classify_vsr(vendor: &GpuVendor, name: &str) -> (bool, VsrMethod) {
    let upper = name.to_uppercase();
    match vendor {
        GpuVendor::Nvidia => {
            // RTX 20xx+ support D3D11 VSR.
            if upper.contains("RTX") {
                (true, VsrMethod::D3d11Nvidia)
            } else {
                (false, VsrMethod::SoftwareFsr)
            }
        }
        GpuVendor::Intel => {
            // Arc or Iris Xe support D3D11 Intel VSR.
            if upper.contains("ARC") || upper.contains("IRIS XE") {
                (true, VsrMethod::D3d11Intel)
            } else {
                (false, VsrMethod::SoftwareFsr)
            }
        }
        GpuVendor::Amd => {
            // AMD RSR is driver-level (RX 5000+).
            if upper.contains("RX 5")
                || upper.contains("RX 6")
                || upper.contains("RX 7")
                || upper.contains("RX 8")
                || upper.contains("RX 9")
            {
                (true, VsrMethod::AmdDriverRsr)
            } else {
                (false, VsrMethod::SoftwareFsr)
            }
        }
        _ => (false, VsrMethod::SoftwareLanczos),
    }
}

// ── Linux sysfs detection ───────────────────────────

#[cfg(target_os = "linux")]
fn detect_gpu_linux() -> GpuInfo {
    let vendor_path = "/sys/class/drm/card0/device/vendor";
    let vendor_str = match std::fs::read_to_string(vendor_path) {
        Ok(s) => s.trim().to_string(),
        Err(_) => return GpuInfo::default(),
    };

    let vendor = match vendor_str.as_str() {
        "0x10de" => GpuVendor::Nvidia,
        "0x1002" => GpuVendor::Amd,
        "0x8086" => GpuVendor::Intel,
        _ => GpuVendor::Unknown,
    };

    // Read device name if available.
    let name = std::fs::read_to_string("/sys/class/drm/card0/device/label")
        .unwrap_or_else(|_| format!("{vendor_str} GPU"))
        .trim()
        .to_string();

    // Linux: no HW VSR, software methods only.
    GpuInfo {
        vendor,
        name,
        vram_mb: Option::None,
        supports_hw_vsr: false,
        vsr_method: VsrMethod::SoftwareFsr,
    }
}

// ── macOS placeholder ───────────────────────────────

#[cfg(target_os = "macos")]
fn detect_gpu_macos() -> GpuInfo {
    // Actual Metal detection would require an
    // Objective-C bridge. Placeholder: assume Apple
    // Silicon with MetalFX Spatial support.
    GpuInfo {
        vendor: GpuVendor::Apple,
        name: "Apple GPU".to_string(),
        vram_mb: Option::None,
        supports_hw_vsr: true,
        vsr_method: VsrMethod::MetalFxSpatial,
    }
}

// ── Tests ───────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_gpu_returns_valid_info() {
        let info = detect_gpu();
        // Should not panic, and name should be
        // non-empty.
        assert!(!info.name.is_empty());
    }

    #[test]
    fn test_gpu_info_serialization() {
        let info = GpuInfo {
            vendor: GpuVendor::Nvidia,
            name: "NVIDIA GeForce RTX 4090".to_string(),
            vram_mb: Some(24576),
            supports_hw_vsr: true,
            vsr_method: VsrMethod::D3d11Nvidia,
        };

        let json = serde_json::to_string(&info).unwrap();
        let deser: GpuInfo = serde_json::from_str(&json).unwrap();

        assert_eq!(deser.vendor, GpuVendor::Nvidia);
        assert_eq!(deser.name, "NVIDIA GeForce RTX 4090");
        assert_eq!(deser.vram_mb, Some(24576));
        assert!(deser.supports_hw_vsr);
        assert_eq!(deser.vsr_method, VsrMethod::D3d11Nvidia);
    }

    #[test]
    fn test_default_gpu_info() {
        let info = GpuInfo::default();
        assert_eq!(info.vendor, GpuVendor::Unknown);
        assert_eq!(info.name, "Unknown");
        assert_eq!(info.vram_mb, Option::None);
        assert!(!info.supports_hw_vsr);
        assert_eq!(info.vsr_method, VsrMethod::None);
    }

    #[test]
    fn test_phase4_vsr_methods_serialize() {
        let methods = [
            (VsrMethod::RtxVideoSdk, "\"RtxVideoSdk\""),
            (VsrMethod::CoreMlSuperRes, "\"CoreMlSuperRes\""),
            (VsrMethod::QualcommGsr, "\"QualcommGsr\""),
        ];
        for (method, expected) in methods {
            let json = serde_json::to_string(&method).unwrap();
            assert_eq!(json, expected);
            let deser: VsrMethod = serde_json::from_str(&json).unwrap();
            assert_eq!(deser, method);
        }
    }
}
