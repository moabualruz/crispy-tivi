use criterion::{criterion_group, criterion_main, Criterion};

fn scroll_benchmark(_c: &mut Criterion) {
    // Benchmarks will be added in later tasks.
}

criterion_group!(benches, scroll_benchmark);
criterion_main!(benches);
