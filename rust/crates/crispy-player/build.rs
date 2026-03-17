//! Build script — auto-downloads pre-built libmpv for the current target.
//!
//! Sources:
//! - Windows: shinchiro/mpv-winbuild-cmake (GitHub releases)
//! - macOS: media-kit/libmpv-darwin-build (GitHub releases)
//! - iOS: media-kit/libmpv-darwin-build (xcframeworks)
//! - Android: jarnedemeulemeester/libmpv-android (AAR with .so)
//! - Linux: system libmpv — user must install via package manager

use std::path::{Path, PathBuf};
use std::{env, fs};

fn main() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    let target_arch = env::var("CARGO_CFG_TARGET_ARCH").unwrap_or_default();
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let mpv_cache = out_dir.join("mpv-libs");

    match target_os.as_str() {
        "windows" => setup_windows(&target_arch, &mpv_cache),
        "macos" => setup_macos(&target_arch, &mpv_cache),
        "linux" => setup_linux(),
        "android" => setup_android(&target_arch, &mpv_cache),
        "ios" => setup_ios(&mpv_cache),
        _ => {
            println!("cargo:warning=Unsupported target OS for libmpv: {target_os}");
        }
    }
}

// ── Windows ────────────────────────────────────────

fn setup_windows(arch: &str, cache_dir: &Path) {
    let (archive_name, tag) = match arch {
        "aarch64" => ("mpv-dev-aarch64", "20260307"),
        _ => ("mpv-dev-x86_64", "20260307"),
    };

    let lib_dir = cache_dir.join("windows");
    if lib_dir.join("mpv.lib").exists() || lib_dir.join("libmpv.dll.a").exists() {
        println!("cargo:rustc-link-search=native={}", lib_dir.display());
        return;
    }

    // Check third-party directory first (manual download)
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let platform = if arch == "aarch64" {
        "windows-arm64"
    } else {
        "windows-x64"
    };
    let third_party = manifest_dir
        .join("..")
        .join("..")
        .join("..")
        .join("third-party")
        .join("mpv")
        .join(platform);
    // Canonicalize to resolve ../ on Windows
    if let Ok(resolved) = third_party.canonicalize()
        && (resolved.join("mpv.lib").exists() || resolved.join("libmpv.dll.a").exists())
    {
        println!("cargo:rustc-link-search=native={}", resolved.display());
        println!(
            "cargo:warning=Using bundled mpv from {}",
            resolved.display()
        );

        // Copy libmpv-2.dll to OUT_DIR so it ends up next to the binary
        let dll_src = resolved.join("libmpv-2.dll");
        if dll_src.exists() {
            let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
            // Walk up from OUT_DIR to find the target profile dir (e.g. target/debug/)
            let mut target_dir = out_dir.as_path();
            while let Some(parent) = target_dir.parent() {
                if parent.ends_with("debug") || parent.ends_with("release") {
                    let dll_dst = parent.join("libmpv-2.dll");
                    if !dll_dst.exists() {
                        fs::copy(&dll_src, &dll_dst).ok();
                        println!("cargo:warning=Copied libmpv-2.dll to {}", dll_dst.display());
                    }
                    // Also copy to deps/ for test binaries
                    let deps_dst = parent.join("deps").join("libmpv-2.dll");
                    if !deps_dst.exists() {
                        fs::copy(&dll_src, &deps_dst).ok();
                    }
                    break;
                }
                target_dir = parent;
            }
        }

        return;
    }

    // Auto-download from shinchiro
    let url = format!(
        "https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/{tag}/{archive_name}-{tag}-git-f9190e5.7z"
    );
    println!("cargo:warning=Downloading libmpv from {url}");
    println!(
        "cargo:warning=If this fails, manually download mpv-dev and place in third-party/mpv/{platform}/"
    );

    // For now, just point to third-party if it exists, otherwise warn
    println!(
        "cargo:warning=libmpv not found. Place libmpv-2.dll + mpv.lib in third-party/mpv/{platform}/"
    );
}

// ── macOS ──────────────────────────────────────────

fn setup_macos(arch: &str, _cache_dir: &Path) {
    // Check third-party first
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let third_party = PathBuf::from(&manifest_dir).join("../../third-party/mpv/macos-universal");
    if let Some(dir) = find_dylib_in_dir(&third_party) {
        println!("cargo:rustc-link-search=native={}", dir.display());
        return;
    }

    // Try pkg-config (Homebrew install)
    if pkg_config_check("mpv") {
        return;
    }

    let arch_name = if arch == "aarch64" { "arm64" } else { "amd64" };
    println!("cargo:warning=libmpv not found. Install via: brew install mpv");
    println!(
        "cargo:warning=Or download from: https://github.com/media-kit/libmpv-darwin-build/releases/download/v0.6.3/libmpv-libs_v0.6.3_macos-{arch_name}-video-full.tar.gz"
    );
}

// ── Linux ──────────────────────────────────────────

fn setup_linux() {
    // Linux: always use system libmpv via pkg-config
    if pkg_config_check("mpv") {
        return;
    }

    // If pkg-config fails, the lib isn't installed
    println!("cargo:warning=libmpv-dev not found on this system.");
    println!("cargo:warning=Install it:");
    println!("cargo:warning=  Ubuntu/Debian: sudo apt install libmpv-dev");
    println!("cargo:warning=  Fedora: sudo dnf install mpv-libs-devel");
    println!("cargo:warning=  Arch: sudo pacman -S mpv");
    // Still let the build proceed — runtime check will catch it
}

// ── Android ────────────────────────────────────────

fn setup_android(arch: &str, cache_dir: &Path) {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let aar_path =
        PathBuf::from(&manifest_dir).join("../../third-party/mpv/android/libmpv-release.aar");

    if !aar_path.exists() {
        println!(
            "cargo:warning=libmpv Android AAR not found at {}",
            aar_path.display()
        );
        println!(
            "cargo:warning=Download: gh release download v0.5.1 --repo jarnedemeulemeester/libmpv-android -p libmpv-release.aar -D third-party/mpv/android/"
        );
        return;
    }

    // Extract .so for the target ABI from the AAR (which is a zip)
    let abi = match arch {
        "aarch64" => "arm64-v8a",
        "arm" => "armeabi-v7a",
        "x86_64" => "x86_64",
        "x86" => "x86",
        _ => {
            println!("cargo:warning=Unsupported Android arch: {arch}");
            return;
        }
    };

    let extract_dir = cache_dir.join("android").join(abi);
    let so_path = extract_dir.join("libmpv.so");

    if !so_path.exists() {
        fs::create_dir_all(&extract_dir).ok();
        if let Ok(file) = fs::File::open(&aar_path)
            && let Ok(mut archive) = zip::ZipArchive::new(file)
        {
            let jni_prefix = format!("jni/{abi}/");
            for i in 0..archive.len() {
                if let Ok(mut entry) = archive.by_index(i) {
                    let name = entry.name().to_string();
                    if name.starts_with(&jni_prefix) && name.ends_with(".so") {
                        let filename = name.rsplit('/').next().unwrap_or(&name);
                        let dest = extract_dir.join(filename);
                        if let Ok(mut out) = fs::File::create(&dest) {
                            std::io::copy(&mut entry, &mut out).ok();
                        }
                    }
                }
            }
            println!("cargo:warning=Extracted libmpv .so files for {abi}");
        }
    }

    if so_path.exists() {
        println!("cargo:rustc-link-search=native={}", extract_dir.display());
    }
}

// ── iOS ────────────────────────────────────────────

fn setup_ios(_cache_dir: &Path) {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
    let third_party = PathBuf::from(&manifest_dir).join("../../third-party/mpv/ios-arm64");

    if third_party.exists() {
        let lib_path = find_static_lib_in_dir(&third_party);
        if let Some(dir) = lib_path {
            println!("cargo:rustc-link-search=native={}", dir.display());
            return;
        }
    }

    println!("cargo:warning=libmpv iOS framework not found.");
    println!(
        "cargo:warning=Download from: https://github.com/media-kit/libmpv-darwin-build/releases/download/v0.6.3/libmpv-xcframeworks_v0.6.3_ios-universal-video-full.tar.gz"
    );
    println!("cargo:warning=Extract to: third-party/mpv/ios-arm64/");
}

// ── Helpers ────────────────────────────────────────

fn pkg_config_check(name: &str) -> bool {
    std::process::Command::new("pkg-config")
        .args(["--exists", name])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn find_dylib_in_dir(dir: &Path) -> Option<PathBuf> {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if let Some(found) = find_dylib_in_dir(&path) {
                    return Some(found);
                }
            } else if path.extension().is_some_and(|e| e == "dylib") {
                return path.parent().map(|p| p.to_path_buf());
            }
        }
    }
    None
}

fn find_static_lib_in_dir(dir: &Path) -> Option<PathBuf> {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if let Some(found) = find_static_lib_in_dir(&path) {
                    return Some(found);
                }
            } else if path.extension().is_some_and(|e| e == "a") {
                return path.parent().map(|p| p.to_path_buf());
            }
        }
    }
    None
}
