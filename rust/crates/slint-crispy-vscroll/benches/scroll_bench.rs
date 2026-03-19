use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_physics_friction(c: &mut Criterion) {
    c.bench_function("friction_decay", |b| {
        b.iter(|| {
            slint_crispy_vscroll::physics::momentum::apply_friction_decay(
                black_box(1000.0),
                black_box(0.97),
                black_box(0.016),
            )
        })
    });
}

fn bench_physics_velocity_cap(c: &mut Criterion) {
    c.bench_function("velocity_cap", |b| {
        b.iter(|| {
            slint_crispy_vscroll::physics::momentum::apply_velocity_cap(
                black_box(9500.0),
                black_box(3000.0),
            )
        })
    });
}

fn bench_rubber_band(c: &mut Criterion) {
    c.bench_function("rubber_band_displacement", |b| {
        b.iter(|| {
            slint_crispy_vscroll::physics::rubber_band::rubber_band_displacement(
                black_box(300.0),
                black_box(600.0),
                black_box(0.55),
            )
        })
    });
}

fn bench_spring_step(c: &mut Criterion) {
    c.bench_function("spring_step", |b| {
        b.iter(|| {
            slint_crispy_vscroll::physics::spring::spring_step(
                black_box(0.0),
                black_box(0.0),
                black_box(100.0),
                black_box(300.0),
                black_box(28.0),
                black_box(1.0_f32 / 60.0),
            )
        })
    });
}

fn bench_visible_range(c: &mut Criterion) {
    c.bench_function("visible_range_10k_items", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::visible_range_uniform(
                black_box(5000.0),
                black_box(80.0),
                black_box(400.0),
                black_box(10000),
                black_box(2),
            )
        })
    });
}

fn bench_visible_range_100k_items(c: &mut Criterion) {
    c.bench_function("visible_range_100k_items", |b| {
        b.iter(|| {
            slint_crispy_vscroll::layout::vertical::visible_range_uniform(
                black_box(400000.0),
                black_box(80.0),
                black_box(400.0),
                black_box(100_000),
                black_box(2),
            )
        })
    });
}

fn bench_recycle(c: &mut Criterion) {
    c.bench_function("recycle_shift_5", |b| {
        b.iter(|| {
            slint_crispy_vscroll::slots::recycler::compute_recycle(
                black_box(0..20),
                black_box(5..25),
            )
        })
    });
}

fn bench_recycle_shift_1(c: &mut Criterion) {
    c.bench_function("recycle_shift_1", |b| {
        b.iter(|| {
            slint_crispy_vscroll::slots::recycler::compute_recycle(
                black_box(0..20),
                black_box(1..21),
            )
        })
    });
}

criterion_group!(
    benches,
    bench_physics_friction,
    bench_physics_velocity_cap,
    bench_rubber_band,
    bench_spring_step,
    bench_visible_range,
    bench_visible_range_100k_items,
    bench_recycle,
    bench_recycle_shift_1,
);
criterion_main!(benches);
