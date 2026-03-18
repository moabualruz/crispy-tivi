/// Smoke test: CrispyService can be instantiated with an in-memory database.
use crispy_server::CrispyService;

#[test]
fn test_crispy_service_open_in_memory() {
    let service = CrispyService::open_in_memory();
    assert!(
        service.is_ok(),
        "CrispyService::open_in_memory() must succeed"
    );
}

#[test]
fn test_crispy_service_get_sources_empty_on_fresh_db() {
    let service = CrispyService::open_in_memory().expect("open in-memory");
    let sources = service.get_sources();
    assert!(
        sources.is_ok(),
        "get_sources() must not error on fresh db"
    );
    assert!(
        sources.unwrap().is_empty(),
        "fresh db has no sources"
    );
}
