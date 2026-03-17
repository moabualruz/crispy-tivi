slint::include_modules!();

// Force discrete GPU on hybrid laptops (NVIDIA Optimus / AMD PowerXpress)
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub static NvOptimusEnablement: u32 = 1;
#[cfg(target_os = "windows")]
#[unsafe(no_mangle)]
pub static AmdPowerXpressRequestHighPerformance: i32 = 1;

mod app;
mod cache;
mod data;
mod data_engine;
mod events;
mod i18n;
#[allow(dead_code)]
mod provider;
mod sync;
mod sync_task;

fn main() -> anyhow::Result<()> {
    // Initialize tracing with configurable filter
    let filter = std::env::var("CRISPY_LOG")
        .unwrap_or_else(|_| "info,crispy_ui=debug,crispy_core=info".to_string());
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::new(filter))
        .init();

    tracing::info!(version = env!("CARGO_PKG_VERSION"), "CrispyTivi starting");

    // Tokio runtime for async sync tasks — must outlive the event loop.
    let rt = tokio::runtime::Runtime::new()?;

    let ui = AppWindow::new()?;

    // app::init creates MpvBackend and wires all Slint callbacks.
    // It returns the raw mpv handle so the render context (VideoUnderlay) shares
    // the exact same mpv instance — playback commands and GL rendering go to one handle.
    let (_service, mpv_render_handle) = app::init(&ui, rt.handle())?;

    // Set up Slint rendering notifier for the libmpv video underlay.
    //
    // The VideoUnderlay bridges libmpv's OpenGL renderer into Slint's GL context
    // via an FBO (Layer 0). Slint's UI canvas renders transparently on top (Layer 1).
    //
    // The underlay is held in Rc<RefCell<Option<...>>> so it can be initialised on
    // the first RenderingSetup call and released on RenderingTeardown — all on the
    // GL thread, which is the requirement for all glow/libmpv-sys GL calls.
    use crispy_player::video_underlay::VideoUnderlay;
    use std::{cell::RefCell, rc::Rc};

    let underlay_cell: Rc<RefCell<Option<VideoUnderlay>>> = Rc::new(RefCell::new(None));

    if let Some(raw_handle) = mpv_render_handle {
        let ui_weak = ui.as_weak();
        let underlay_cell_clone = underlay_cell.clone();

        match ui
            .window()
            .set_rendering_notifier(move |state, graphics_api| {
                match state {
                    slint::RenderingState::RenderingSetup => {
                        // Retrieve the OpenGL proc-address function from Slint.
                        let get_proc_address =
                            if let slint::GraphicsAPI::NativeOpenGL { get_proc_address } =
                                graphics_api
                            {
                                get_proc_address
                            } else {
                                tracing::warn!("Non-OpenGL backend — video underlay not available");
                                return;
                            };

                        // Determine initial window size in physical pixels.
                        let (w, h) = if let Some(ui) = ui_weak.upgrade() {
                            let sz = ui.window().size();
                            (sz.width.max(1), sz.height.max(1))
                        } else {
                            (1920, 1080)
                        };

                        // Safety: raw_handle is valid (initialised above), GL context is
                        // current on this thread (guaranteed by Slint's RenderingSetup).
                        match unsafe { VideoUnderlay::new(raw_handle, get_proc_address, w, h) } {
                            Ok(underlay) => {
                                tracing::info!("VideoUnderlay created ({}×{})", w, h);
                                *underlay_cell_clone.borrow_mut() = Some(underlay);
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
                        // Request another frame if the underlay has a pending redraw.
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
                        // Drop underlay before the GL context is destroyed.
                        // The mpv handle is owned by MpvBackend — do NOT call
                        // mpv_destroy here; MpvBackend's Drop handles it.
                        drop(underlay_cell_clone.borrow_mut().take());
                        tracing::info!("VideoUnderlay released");
                    }

                    _ => {}
                }
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

    tracing::info!("UI ready, entering event loop");
    ui.run()?;

    // Keep the runtime alive until after the event loop exits.
    drop(rt);

    Ok(())
}
