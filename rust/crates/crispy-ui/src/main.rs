slint::include_modules!();

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

    let ui = AppWindow::new()?;

    let _service = app::init(&ui)?;

    tracing::info!("UI ready, entering event loop");
    ui.run()?;

    Ok(())
}
