use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn bench_spring_tick_600_frames(c: &mut Criterion) {
    c.bench_function("spring_tick_600_frames", |b| {
        b.iter(|| {
            let mut pos = 0.0f32;
            let mut vel = 0.0f32;
            let target = 100.0f32;
            let dt = 1.0f32 / 60.0;
            for _ in 0..600 {
                (pos, vel) = slint_crispy_vscroll::physics::spring::spring_step(
                    black_box(pos),
                    black_box(vel),
                    black_box(target),
                    black_box(300.0),
                    black_box(28.0),
                    black_box(dt),
                );
            }
            (pos, vel)
        })
    });
}

fn bench_rubber_band_series(c: &mut Criterion) {
    c.bench_function("rubber_band_100_calls", |b| {
        b.iter(|| {
            let mut total = 0.0f32;
            for i in 0..100 {
                total += slint_crispy_vscroll::physics::rubber_band::rubber_band_displacement(
                    black_box(i as f32 * 5.0),
                    black_box(600.0),
                    black_box(0.55),
                );
            }
            total
        })
    });
}

fn bench_friction_600_frames(c: &mut Criterion) {
    c.bench_function("friction_decay_600_frames", |b| {
        b.iter(|| {
            let mut v = 2000.0f32;
            let dt = 1.0f32 / 60.0;
            for _ in 0..600 {
                v = slint_crispy_vscroll::physics::momentum::apply_friction_decay(
                    black_box(v),
                    black_box(0.97),
                    black_box(dt),
                );
            }
            v
        })
    });
}

criterion_group!(
    benches,
    bench_spring_tick_600_frames,
    bench_rubber_band_series,
    bench_friction_600_frames,
);
criterion_main!(benches);
