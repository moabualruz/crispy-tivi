//! Eager, multi-queue image loader for CrispyTivi UI.
//!
//! Architecture:
//! - 3 dedicated async queues: channels, movies, series
//! - Each queue has its own consumer task with high concurrency (16 workers each)
//! - Requests are dispatched async and consumed in parallel
//! - UI update: each completed image triggers invoke_from_event_loop + request_redraw

use std::sync::Arc;

use slint::{ComponentHandle, Model};
use tokio::sync::mpsc;

use crate::image_cache::ImageCache;

// ── Request types ────────────────────────────────────────────────────────────

struct ImageRequest {
    idx: usize,
    url: String,
}

enum ModelKind {
    Channel,
    Movie,
    Series,
}

// ── ImageLoader ──────────────────────────────────────────────────────────────

/// Manages 3 dedicated image loading queues with independent consumer tasks.
#[derive(Clone)]
pub struct ImageLoader {
    channel_tx: mpsc::UnboundedSender<ImageRequest>,
    movie_tx: mpsc::UnboundedSender<ImageRequest>,
    series_tx: mpsc::UnboundedSender<ImageRequest>,
}

impl ImageLoader {
    /// Spawn 3 consumer tasks (one per content type) and return the loader handle.
    pub fn spawn(ui_weak: slint::Weak<super::AppWindow>, image_cache: Arc<ImageCache>) -> Self {
        let (channel_tx, channel_rx) = mpsc::unbounded_channel();
        let (movie_tx, movie_rx) = mpsc::unbounded_channel();
        let (series_tx, series_rx) = mpsc::unbounded_channel();

        Self::spawn_consumer(
            channel_rx,
            ModelKind::Channel,
            ui_weak.clone(),
            image_cache.clone(),
            16,
        );
        Self::spawn_consumer(
            movie_rx,
            ModelKind::Movie,
            ui_weak.clone(),
            image_cache.clone(),
            16,
        );
        Self::spawn_consumer(series_rx, ModelKind::Series, ui_weak, image_cache, 16);

        Self {
            channel_tx,
            movie_tx,
            series_tx,
        }
    }

    /// Enqueue images for channels in viewport range only.
    pub fn load_channels(
        &self,
        ui_weak: &slint::Weak<super::AppWindow>,
        viewport: Option<(usize, usize)>,
    ) {
        let Some(ui) = ui_weak.upgrade() else { return };
        let model = ui.global::<super::AppState>().get_channels();
        let total = model.row_count();
        let (start, count) = viewport.unwrap_or((0, total));
        let end = (start + count).min(total);
        let mut enqueued = 0u32;
        let mut skipped_cached = 0u32;
        let mut skipped_no_url = 0u32;
        for i in start..end {
            if let Some(item) = model.row_data(i) {
                if item.logo_url.is_empty() {
                    skipped_no_url += 1;
                    continue;
                }
                if item.logo.size().width > 0 {
                    skipped_cached += 1;
                    continue;
                }
                enqueued += 1;
                let _ = self.channel_tx.send(ImageRequest {
                    idx: i,
                    url: item.logo_url.to_string(),
                });
            }
        }
        tracing::debug!(
            start,
            end,
            total,
            enqueued,
            skipped_cached,
            skipped_no_url,
            "[IMG] load_channels"
        );
    }

    /// Enqueue images for movies in viewport range only.
    pub fn load_movies(
        &self,
        ui_weak: &slint::Weak<super::AppWindow>,
        viewport: Option<(usize, usize)>,
    ) {
        let Some(ui) = ui_weak.upgrade() else { return };
        let model = ui.global::<super::AppState>().get_movies();
        let total = model.row_count();
        let (start, count) = viewport.unwrap_or((0, total));
        let end = (start + count).min(total);
        let mut enqueued = 0u32;
        let mut skipped_cached = 0u32;
        let mut skipped_no_url = 0u32;
        for i in start..end {
            if let Some(item) = model.row_data(i) {
                if item.poster_url.is_empty() {
                    skipped_no_url += 1;
                    continue;
                }
                if item.poster.size().width > 0 {
                    skipped_cached += 1;
                    continue;
                }
                enqueued += 1;
                let _ = self.movie_tx.send(ImageRequest {
                    idx: i,
                    url: item.poster_url.to_string(),
                });
            }
        }
        tracing::debug!(
            start,
            end,
            total,
            enqueued,
            skipped_cached,
            skipped_no_url,
            "[IMG] load_movies"
        );
    }

    /// Enqueue images for series in viewport range only.
    pub fn load_series(
        &self,
        ui_weak: &slint::Weak<super::AppWindow>,
        viewport: Option<(usize, usize)>,
    ) {
        let Some(ui) = ui_weak.upgrade() else { return };
        let model = ui.global::<super::AppState>().get_series();
        let total = model.row_count();
        let (start, count) = viewport.unwrap_or((0, total));
        let end = (start + count).min(total);
        let mut enqueued = 0u32;
        let mut skipped_cached = 0u32;
        let mut skipped_no_url = 0u32;
        for i in start..end {
            if let Some(item) = model.row_data(i) {
                if item.poster_url.is_empty() {
                    skipped_no_url += 1;
                    continue;
                }
                if item.poster.size().width > 0 {
                    skipped_cached += 1;
                    continue;
                }
                enqueued += 1;
                let _ = self.series_tx.send(ImageRequest {
                    idx: i,
                    url: item.poster_url.to_string(),
                });
            }
        }
        tracing::debug!(
            start,
            end,
            total,
            enqueued,
            skipped_cached,
            skipped_no_url,
            "[IMG] load_series"
        );
    }

    /// Spawn a consumer task that drains a queue with N concurrent workers.
    fn spawn_consumer(
        mut rx: mpsc::UnboundedReceiver<ImageRequest>,
        kind: ModelKind,
        ui_weak: slint::Weak<super::AppWindow>,
        cache: Arc<ImageCache>,
        concurrency: usize,
    ) {
        tokio::spawn(async move {
            let semaphore = Arc::new(tokio::sync::Semaphore::new(concurrency));

            while let Some(req) = rx.recv().await {
                let cache = Arc::clone(&cache);
                let sem = Arc::clone(&semaphore);
                let ui_w = ui_weak.clone();

                let is_channel = matches!(kind, ModelKind::Channel);
                let is_movie = matches!(kind, ModelKind::Movie);

                tokio::spawn(async move {
                    let _permit = match sem.acquire().await {
                        Ok(p) => p,
                        Err(_) => return,
                    };

                    let Some(buf) = cache.get_image_buffer(&req.url).await else {
                        return;
                    };

                    let idx = req.idx;
                    slint::invoke_from_event_loop(move || {
                        let Some(ui) = ui_w.upgrade() else { return };
                        let app = ui.global::<super::AppState>();
                        let img = slint::Image::from_rgba8(buf);

                        if is_channel {
                            let model = app.get_channels();
                            if let Some(mut item) = model.row_data(idx)
                                && item.logo.size().width == 0
                            {
                                item.logo = img;
                                model.set_row_data(idx, item);
                            }
                        } else if is_movie {
                            let model = app.get_movies();
                            if let Some(mut item) = model.row_data(idx)
                                && item.poster.size().width == 0
                            {
                                item.poster = img;
                                model.set_row_data(idx, item);
                            }
                        } else {
                            let model = app.get_series();
                            if let Some(mut item) = model.row_data(idx)
                                && item.poster.size().width == 0
                            {
                                item.poster = img;
                                model.set_row_data(idx, item);
                            }
                        }

                        ui.window().request_redraw();
                    })
                    .expect("Slint event loop must be running");
                });
            }
        });
    }
}
