slint::include_modules!();

// Force discrete GPU on hybrid laptops (NVIDIA Optimus / AMD PowerXpress)
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub static NvOptimusEnablement: u32 = 1;
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub static AmdPowerXpressRequestHighPerformance: i32 = 1;

mod app;
mod data;
mod i18n;
#[allow(dead_code)]
mod provider;

fn main() -> anyhow::Result<()> {
    // Initialize tracing with configurable filter
    let filter = std::env::var("CRISPY_LOG")
        .unwrap_or_else(|_| "info,crispy_ui=debug,crispy_core=info".to_string());
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::new(filter))
        .init();

    tracing::info!(version = env!("CARGO_PKG_VERSION"), "CrispyTivi starting");

    // Check libmpv availability (Linux: graceful shutdown with install instructions)
    if let Err(msg) = crispy_player::check_libmpv_available() {
        tracing::error!("libmpv check failed");
        eprintln!("\n{msg}\n");
        std::process::exit(1);
    }
    tracing::info!("libmpv available");

    let ui = AppWindow::new()?;

    let _service = app::init(&ui)?;

    tracing::info!("UI ready, entering event loop");
    ui.run()?;

    Ok(())
}
