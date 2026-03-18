/// Smoke test: crispy-core M3U parser returns expected channel count from fixture.
use crispy_core::parsers::m3u::parse_m3u;

#[test]
fn test_parse_m3u_fixture_returns_five_channels() {
    let content = include_str!("fixtures/sources/sample.m3u");
    let result = parse_m3u(content);
    assert_eq!(
        result.channels.len(),
        5,
        "sample.m3u should produce 5 channels, got {}",
        result.channels.len()
    );
    assert!(result.errors.is_empty(), "no parse errors expected");
}

#[test]
fn test_parse_m3u_fixture_channel_names() {
    let content = include_str!("fixtures/sources/sample.m3u");
    let result = parse_m3u(content);
    let names: Vec<&str> = result.channels.iter().map(|c| c.name.as_str()).collect();
    assert!(names.contains(&"BBC One"), "expected BBC One in channels");
    assert!(names.contains(&"CNN International"), "expected CNN International");
    assert!(names.contains(&"ESPN"), "expected ESPN");
}

#[test]
fn test_parse_m3u_fixture_groups() {
    let content = include_str!("fixtures/sources/sample.m3u");
    let result = parse_m3u(content);
    let bbc = result
        .channels
        .iter()
        .find(|c| c.name == "BBC One")
        .expect("BBC One must be present");
    assert_eq!(bbc.channel_group.as_deref(), Some("UK News"));
}
