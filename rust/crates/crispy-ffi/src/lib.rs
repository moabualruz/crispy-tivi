use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShellContract {
    pub startup_route: String,
    pub top_level_routes: Vec<String>,
    pub settings_groups: Vec<String>,
}

pub fn mock_shell_contract() -> ShellContract {
    ShellContract {
        startup_route: "Home".to_owned(),
        top_level_routes: vec![
            "Home".to_owned(),
            "Live TV".to_owned(),
            "Media".to_owned(),
            "Search".to_owned(),
            "Settings".to_owned(),
        ],
        settings_groups: vec![
            "General".to_owned(),
            "Playback".to_owned(),
            "Sources".to_owned(),
            "Appearance".to_owned(),
            "System".to_owned(),
        ],
    }
}

pub fn mock_shell_contract_json() -> String {
    serde_json::to_string_pretty(&mock_shell_contract())
        .expect("mock shell contract serialization should succeed")
}

#[cfg(test)]
mod tests {
    use super::{ShellContract, mock_shell_contract, mock_shell_contract_json};

    #[test]
    fn json_contract_round_trips() {
        let json = mock_shell_contract_json();
        let parsed: ShellContract =
            serde_json::from_str(&json).expect("mock shell contract should parse");

        assert_eq!(parsed, mock_shell_contract());
        assert!(!parsed.top_level_routes.iter().any(|route| route == "Sources"));
        assert!(!parsed.top_level_routes.iter().any(|route| route == "Player"));
        assert!(parsed.settings_groups.iter().any(|group| group == "Sources"));
    }
}
