//! Group icon matching algorithm.
//!
//! Ports the pattern-matching logic from Dart
//! `group_icon_helper.dart` that maps group names to
//! Material icon identifiers.

/// Match a group name to an icon identifier string.
///
/// Case-insensitive pattern matching against ~14
/// categories. Returns the Material icon name string
/// (e.g., "sports_soccer", "movie", etc.). Unknown
/// groups return "folder".
pub fn match_group_icon(group_name: &str) -> String {
    let lower = group_name.to_lowercase();

    if lower.contains("favorite") {
        return "star".to_string();
    }
    if lower.contains("sport") {
        return "sports_soccer".to_string();
    }
    if lower.contains("news") {
        return "newspaper".to_string();
    }
    if lower.contains("movie") {
        return "movie".to_string();
    }
    if lower.contains("music") {
        return "music_note".to_string();
    }
    if lower.contains("kid") || lower.contains("child") {
        return "child_care".to_string();
    }
    if lower.contains("documentary") || lower.contains("doc") {
        return "video_library".to_string();
    }
    if lower.contains("entertainment") {
        return "theater_comedy".to_string();
    }
    if lower.contains("general") {
        return "tv".to_string();
    }
    if lower.contains("religious") || lower.contains("faith") {
        return "church".to_string();
    }
    if lower.contains("local") {
        return "location_on".to_string();
    }
    if lower.contains("international") {
        return "language".to_string();
    }
    if lower.contains("premium") || lower.contains("hd") {
        return "hd".to_string();
    }
    if lower.contains("xxx") || lower.contains("adult") {
        return "eighteen_up_rating".to_string();
    }

    "folder".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sports_group() {
        assert_eq!(match_group_icon("Sports HD"), "sports_soccer");
        assert_eq!(match_group_icon("SPORTS"), "sports_soccer");
    }

    #[test]
    fn news_group() {
        assert_eq!(match_group_icon("News 24/7"), "newspaper");
    }

    #[test]
    fn movies_group() {
        assert_eq!(match_group_icon("Movies"), "movie");
    }

    #[test]
    fn kids_group() {
        assert_eq!(match_group_icon("Kids Zone"), "child_care");
        assert_eq!(match_group_icon("Children"), "child_care");
    }

    #[test]
    fn music_group() {
        assert_eq!(match_group_icon("Music TV"), "music_note");
    }

    #[test]
    fn documentary_group() {
        assert_eq!(match_group_icon("Documentaries"), "video_library",);
        assert_eq!(match_group_icon("Doc Channel"), "video_library");
    }

    #[test]
    fn entertainment_group() {
        assert_eq!(match_group_icon("Entertainment"), "theater_comedy",);
    }

    #[test]
    fn general_group() {
        assert_eq!(match_group_icon("General"), "tv");
    }

    #[test]
    fn religious_group() {
        assert_eq!(match_group_icon("Religious"), "church");
        assert_eq!(match_group_icon("Faith TV"), "church");
    }

    #[test]
    fn local_group() {
        assert_eq!(match_group_icon("Local Channels"), "location_on");
    }

    #[test]
    fn international_group() {
        assert_eq!(match_group_icon("International"), "language",);
    }

    #[test]
    fn premium_group() {
        assert_eq!(match_group_icon("Premium Pack"), "hd");
        assert_eq!(match_group_icon("HD Channels"), "hd");
    }

    #[test]
    fn adult_group() {
        assert_eq!(match_group_icon("XXX"), "eighteen_up_rating",);
        assert_eq!(match_group_icon("Adult Only"), "eighteen_up_rating",);
    }

    #[test]
    fn favorite_group() {
        assert_eq!(match_group_icon("Favorites"), "star");
    }

    #[test]
    fn unknown_returns_folder() {
        assert_eq!(match_group_icon("Random Group"), "folder");
        assert_eq!(match_group_icon(""), "folder");
    }

    #[test]
    fn case_insensitive() {
        assert_eq!(match_group_icon("SPORTS"), "sports_soccer");
        assert_eq!(match_group_icon("sports"), "sports_soccer");
        assert_eq!(match_group_icon("SpOrTs"), "sports_soccer");
    }
}
