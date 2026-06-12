mod desktop;
mod launch;

pub use desktop::collect_apps;
pub use launch::launch_app;

#[derive(Clone, PartialEq)]
pub struct App {
    pub name: String,
    pub icon: String,
    pub exec: String,
    pub terminal: bool,
    // Precomputed for matching: lowercasing per tile per keystroke adds up
    // on a ~100-tile grid.
    pub name_lc: String,
    // Lowercased Keywords + GenericName, space-joined.
    pub keywords: String,
}

/// Match `query` (already lowercased) against an app. Lower score = better:
/// name prefix < name substring < name subsequence (fuzzy) < keyword match.
/// None = no match.
pub fn score(app: &App, query: &str) -> Option<u32> {
    if query.is_empty() {
        return Some(0);
    }
    if app.name_lc.starts_with(query) {
        return Some(0);
    }
    if app.name_lc.contains(query) {
        return Some(1);
    }
    if is_subsequence(query, &app.name_lc) {
        return Some(2);
    }
    if app.keywords.contains(query) {
        return Some(3);
    }
    None
}

// Fuzzy: every query char appears in order ("ffx" → "firefox").
fn is_subsequence(query: &str, text: &str) -> bool {
    let mut chars = text.chars();
    query.chars().all(|q| chars.any(|t| t == q))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn app(name: &str, keywords: &str) -> App {
        App {
            name: name.into(),
            icon: String::new(),
            exec: "x".into(),
            terminal: false,
            name_lc: name.to_lowercase(),
            keywords: keywords.into(),
        }
    }

    #[test]
    fn ranking() {
        let firefox = app("Firefox", "browser web");
        assert_eq!(score(&firefox, "fire"), Some(0)); // prefix
        assert_eq!(score(&firefox, "fox"), Some(1)); // substring
        assert_eq!(score(&firefox, "ffx"), Some(2)); // fuzzy
        assert_eq!(score(&firefox, "browser"), Some(3)); // keyword
        assert_eq!(score(&firefox, "xyz"), None);
    }

    #[test]
    fn empty_query_matches_all() {
        assert_eq!(score(&app("Anything", ""), ""), Some(0));
    }

    #[test]
    fn subsequence_is_ordered() {
        assert!(is_subsequence("ffx", "firefox"));
        assert!(!is_subsequence("xff", "firefox"));
    }
}
