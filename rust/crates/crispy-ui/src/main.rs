slint::include_modules!();

// Force discrete GPU on hybrid laptops (NVIDIA Optimus / AMD PowerXpress)
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub static NvOptimusEnablement: u32 = 1;
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub static AmdPowerXpressRequestHighPerformance: i32 = 1;

mod cache;
mod data_engine;
mod event_bridge;
#[allow(dead_code)]
mod events;
mod i18n;
mod image_cache;
#[allow(dead_code)]
mod provider;
mod sync_task;

use std::sync::{
    Arc, Mutex,
    atomic::{AtomicBool, Ordering},
};

use crispy_player::mpv_backend::MpvBackend;
use crispy_server::CrispyService;
use slint::ComponentHandle;

/// Resolve the database path from env or default.
fn resolve_db_path() -> String {
    if let Ok(p) = std::env::var("CRISPY_DB_PATH") {
        return p;
    }
    let home = std::env::var("HOME")
        .or_else(|_| std::env::var("USERPROFILE"))
        .unwrap_or_else(|_| ".".to_string());
    let dir = format!("{home}/.crispytivi/data");
    let _ = std::fs::create_dir_all(&dir);
    format!("{dir}/crispy.db")
}

fn main() -> anyhow::Result<()> {
    // Initialize tracing with configurable filter
    let filter = std::env::var("CRISPY_LOG")
        .unwrap_or_else(|_| "info,crispy_ui=debug,crispy_core=info".to_string());
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::new(filter))
        .init();

    tracing::info!(version = env!("CARGO_PKG_VERSION"), "CrispyTivi starting");

    // Tokio runtime for async tasks — must outlive the event loop.
    let rt = tokio::runtime::Runtime::new()?;
    let _guard = rt.enter();

    // ── Database + Service ────────────────────────────────────────────────
    let db_path = resolve_db_path();
    tracing::info!(db_path = %db_path, "Opening database");
    let service = CrispyService::open(&db_path)?;

    // ── Slint UI ──────────────────────────────────────────────────────────
    let ui = AppWindow::new()?;

    // Load persisted theme preference (0=system, 1=dark, 2=light)
    let theme_mode: i32 = service
        .get_setting("theme")
        .ok()
        .flatten()
        .and_then(|v| v.parse().ok())
        .unwrap_or(1);
    ui.global::<Theme>().set_theme_mode(theme_mode);

    // Load persisted language preference
    let lang = service
        .get_setting("language")
        .ok()
        .flatten()
        .unwrap_or_else(|| "en".to_string());
    let app_state = ui.global::<AppState>();
    app_state.set_active_language(lang.clone().into());
    app_state.set_is_rtl(i18n::is_rtl(&lang));
    i18n::set_locale(&lang);

    // Show onboarding if first run (check both keys for backwards compat)
    let is_first_run = service
        .get_setting("onboarding_done")
        .ok()
        .flatten()
        .is_none()
        && service
            .get_setting("onboarding_complete")
            .ok()
            .flatten()
            .is_none();
    if is_first_run {
        tracing::info!("First run detected — showing onboarding");
        ui.global::<OnboardingState>().set_is_active(true);
    }

    // Diagnostics (static info)
    let diag = ui.global::<DiagnosticsState>();
    diag.set_app_version(env!("CARGO_PKG_VERSION").into());
    diag.set_slint_version("1.15".into());
    diag.set_db_path(db_path.into());
    diag.set_log_level(
        std::env::var("CRISPY_LOG")
            .unwrap_or_else(|_| "info".to_string())
            .into(),
    );

    // ── Bounded channels (5 queues) ──────────────────────────────────────
    let (player_tx, player_rx) = tokio::sync::mpsc::channel(64);
    let (high_tx, high_rx) = tokio::sync::mpsc::channel(256);
    let (normal_tx, normal_rx) = tokio::sync::mpsc::channel(128);
    let (sync_result_tx, sync_result_rx) = tokio::sync::mpsc::channel(32);
    let (data_tx, data_rx) = tokio::sync::mpsc::channel(512);

    // ── Wire Slint callbacks → queues ────────────────────────────────────
    event_bridge::wire(&ui, player_tx, high_tx, normal_tx);

    // ── MpvBackend (shared between player handler and data listener) ─────
    let backend = match MpvBackend::new() {
        Ok(b) => {
            tracing::info!("MpvBackend initialized");
            Some(b)
        }
        Err(e) => {
            tracing::warn!(error = %e, "MpvBackend unavailable — playback disabled");
            None
        }
    };

    // Extract raw mpv handle before moving backend into Arc<Mutex>
    let mpv_render_handle: Option<*mut libmpv_sys::mpv_handle> =
        backend.as_ref().map(|b| b.raw_handle());

    let backend_shared: Arc<Mutex<Option<MpvBackend>>> = Arc::new(Mutex::new(backend));

    // Flag: set to true once the OpenGL render context is ready for mpv
    let render_context_ready = Arc::new(AtomicBool::new(false));

    // ── Image cache ─────────────────────────────────────────────────────
    let image_cache = Arc::new(image_cache::ImageCache::new(reqwest::Client::new()));

    // Spawn background cleanup task (every hour)
    {
        let cache_clone = Arc::clone(&image_cache);
        rt.spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
                cache_clone.cleanup_expired().await;
            }
        });
    }

    // ── Spawn player handler (PlayerEvent → MpvBackend) ──────────────────
    event_bridge::spawn_player_handler(ui.as_weak(), player_rx, backend_shared.clone());

    // ── Spawn data listener (DataEvent → Slint properties) ───────────────
    event_bridge::spawn_data_listener(
        ui.as_weak(),
        data_rx,
        backend_shared,
        Arc::clone(&render_context_ready),
        Arc::clone(&image_cache),
    );

    // ── Spawn DataEngine (event loop: queues → cache → DataEvents) ───────
    let engine = data_engine::DataEngine::new(
        service,
        high_rx,
        normal_rx,
        sync_result_rx,
        data_tx,
        sync_result_tx,
        rt.handle().clone(),
    );
    rt.spawn(engine.run());

    // ── Video underlay (libmpv OpenGL → Slint rendering pipeline) ────────
    setup_video_underlay(&ui, mpv_render_handle, Arc::clone(&render_context_ready));

    tracing::info!("UI ready, entering event loop");
    ui.run()?;

    // Keep the runtime alive until after the event loop exits.
    drop(rt);

    Ok(())
}

/// Set up the Slint rendering notifier for the libmpv video underlay.
///
/// The VideoUnderlay bridges libmpv's OpenGL renderer into Slint's GL context
/// via an FBO (Layer 0). Slint's UI canvas renders transparently on top (Layer 1).
fn setup_video_underlay(
    ui: &AppWindow,
    mpv_render_handle: Option<*mut libmpv_sys::mpv_handle>,
    render_context_ready: Arc<AtomicBool>,
) {
    use crispy_player::video_underlay::VideoUnderlay;
    use std::{cell::RefCell, rc::Rc};

    let underlay_cell: Rc<RefCell<Option<VideoUnderlay>>> = Rc::new(RefCell::new(None));

    let Some(raw_handle) = mpv_render_handle else {
        return;
    };

    let ui_weak = ui.as_weak();
    let underlay_cell_clone = underlay_cell.clone();

    match ui
        .window()
        .set_rendering_notifier(move |state, graphics_api| match state {
            slint::RenderingState::RenderingSetup => {
                let get_proc_address =
                    if let slint::GraphicsAPI::NativeOpenGL { get_proc_address } = graphics_api {
                        get_proc_address
                    } else {
                        tracing::warn!("Non-OpenGL backend — video underlay not available");
                        return;
                    };

                let (w, h) = if let Some(ui) = ui_weak.upgrade() {
                    let sz = ui.window().size();
                    (sz.width.max(1), sz.height.max(1))
                } else {
                    (1920, 1080)
                };

                match unsafe { VideoUnderlay::new(raw_handle, get_proc_address, w, h) } {
                    Ok(underlay) => {
                        tracing::info!("VideoUnderlay created ({w}x{h})");
                        *underlay_cell_clone.borrow_mut() = Some(underlay);
                        render_context_ready.store(true, Ordering::Release);
                    }
                    Err(e) => {
                        tracing::error!(error = %e, "VideoUnderlay creation failed");
                    }
                }
            }

            slint::RenderingState::BeforeRendering => {
                if let Some(underlay) = underlay_cell_clone.borrow_mut().as_mut() {
                    let (w, h) = if let Some(ui) = ui_weak.upgrade() {
                        let sz = ui.window().size();
                        (sz.width.max(1) as i32, sz.height.max(1) as i32)
                    } else {
                        (1920, 1080)
                    };

                    if underlay.needs_redraw() {
                        underlay.render(w, h);
                        underlay.draw_underlay();
                    }
                }
            }

            slint::RenderingState::AfterRendering => {
                if underlay_cell_clone
                    .borrow()
                    .as_ref()
                    .is_some_and(|u| u.needs_redraw())
                    && let Some(ui) = ui_weak.upgrade()
                {
                    ui.window().request_redraw();
                }
            }

            slint::RenderingState::RenderingTeardown => {
                drop(underlay_cell_clone.borrow_mut().take());
                tracing::info!("VideoUnderlay released");
            }

            _ => {}
        }) {
        Ok(()) => {
            tracing::info!("Rendering notifier registered");
        }
        Err(slint::SetRenderingNotifierError::Unsupported) => {
            tracing::warn!(
                "set_rendering_notifier unsupported — run with SLINT_BACKEND=GL for video underlay"
            );
        }
        Err(e) => {
            tracing::error!(error = ?e, "Failed to register rendering notifier");
        }
    }
}
