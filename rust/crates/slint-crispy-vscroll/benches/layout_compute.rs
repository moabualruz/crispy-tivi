use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_visible_range_1k(c: &mut Criterion) {
    c.bench_function("visible_range_1k_items", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::visible_range_uniform(
                black_box(2000.0),
                black_box(80.0),
                black_box(400.0),
                black_box(1000),
                black_box(2),
            )
        })
    });
}

fn bench_visible_range_10k(c: &mut Criterion) {
    c.bench_function("visible_range_10k_items", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::visible_range_uniform(
                black_box(5000.0),
                black_box(80.0),
                black_box(400.0),
                black_box(10_000),
                black_box(2),
            )
        })
    });
}

fn bench_visible_range_100k(c: &mut Criterion) {
    c.bench_function("visible_range_100k_items", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::visible_range_uniform(
                black_box(400_000.0),
                black_box(80.0),
                black_box(400.0),
                black_box(100_000),
                black_box(2),
            )
        })
    });
}

fn bench_content_size(c: &mut Criterion) {
    c.bench_function("content_size_100k_items", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::content_size_uniform(
                black_box(100_000),
                black_box(80.0),
            )
        })
    });
}

fn bench_max_scroll_offset(c: &mut Criterion) {
    c.bench_function("max_scroll_offset", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::max_scroll_offset(
                black_box(8_000_000.0),
                black_box(400.0),
            )
        })
    });
}

criterion_group!(
    benches,
    bench_visible_range_1k,
    bench_visible_range_10k,
    bench_visible_range_100k,
    bench_content_size,
    bench_max_scroll_offset,
);
criterion_main!(benches);
