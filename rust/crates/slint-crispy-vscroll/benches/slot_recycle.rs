use criterion::{black_box, criterion_group, criterion_main, Criterion};

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

fn bench_recycle_shift_5(c: &mut Criterion) {
    c.bench_function("recycle_shift_5", |b| {
        b.iter(|| {
            slint_crispy_vscroll::slots::recycler::compute_recycle(
                black_box(0..20),
                black_box(5..25),
            )
        })
    });
}

fn bench_recycle_disjoint(c: &mut Criterion) {
    c.bench_function("recycle_fully_disjoint_20", |b| {
        b.iter(|| {
            slint_crispy_vscroll::slots::recycler::compute_recycle(
                black_box(0..20),
                black_box(1000..1020),
            )
        })
    });
}

fn bench_recycle_large_window_shift_1(c: &mut Criterion) {
    c.bench_function("recycle_100_slot_shift_1", |b| {
        b.iter(|| {
            slint_crispy_vscroll::slots::recycler::compute_recycle(
                black_box(0..100),
                black_box(1..101),
            )
        })
    });
}

criterion_group!(
    benches,
    bench_recycle_shift_1,
    bench_recycle_shift_5,
    bench_recycle_disjoint,
    bench_recycle_large_window_shift_1,
);
criterion_main!(benches);
