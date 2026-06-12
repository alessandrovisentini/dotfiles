use std::collections::HashSet;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use super::App;

fn xdg_data_dirs() -> Vec<PathBuf> {
    let mut out = Vec::new();
    if let Some(home) = env::var_os("XDG_DATA_HOME") {
        out.push(PathBuf::from(home));
    } else if let Some(home) = env::var_os("HOME") {
        out.push(PathBuf::from(home).join(".local/share"));
    }
    let dirs = env::var("XDG_DATA_DIRS")
        .unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    for d in dirs.split(':') {
        if !d.is_empty() {
            out.push(PathBuf::from(d));
        }
    }
    out
}

pub fn collect_apps() -> Vec<App> {
    let mut seen_files = HashSet::new();
    let mut seen_names = HashSet::new();
    let mut apps: Vec<App> = Vec::new();

    for data in xdg_data_dirs() {
        let dir = data.join("applications");
        let entries = match fs::read_dir(&dir) {
            Ok(e) => e,
            Err(_) => continue,
        };
        for ent in entries.flatten() {
            let path = ent.path();
            let fname = match path.file_name().and_then(|s| s.to_str()) {
                Some(s) => s.to_owned(),
                None => continue,
            };
            if !fname.ends_with(".desktop") || !seen_files.insert(fname) {
                continue;
            }
            if let Some(app) = parse_desktop(&path) {
                if seen_names.insert(app.name.clone()) {
                    apps.push(app);
                }
            }
        }
    }
    apps.sort_by_key(|a| a.name.to_lowercase());
    apps
}

fn parse_desktop(path: &Path) -> Option<App> {
    let text = fs::read_to_string(path).ok()?;
    let mut in_section = false;
    let mut name = String::new();
    let mut icon = String::new();
    let mut exec = String::new();
    let mut keywords = String::new();
    let mut generic = String::new();
    let mut terminal = false;
    let mut typ = String::new();
    let mut no_display = false;
    let mut hidden = false;

    for line in text.lines() {
        let line = line.trim_end();
        if line.starts_with('[') {
            in_section = line == "[Desktop Entry]";
            continue;
        }
        if !in_section || line.starts_with('#') {
            continue;
        }
        let (k, v) = match line.split_once('=') {
            Some(kv) => kv,
            None => continue,
        };
        // First-write-wins: skip locale-suffixed duplicates.
        let k = k.trim();
        let v = v.trim();
        match k {
            "Name" if name.is_empty() => name = v.to_string(),
            "Icon" if icon.is_empty() => icon = v.to_string(),
            "Exec" if exec.is_empty() => exec = v.to_string(),
            "Keywords" if keywords.is_empty() => keywords = v.to_string(),
            "GenericName" if generic.is_empty() => generic = v.to_string(),
            "Terminal" if !terminal => {
                terminal = v.eq_ignore_ascii_case("true");
            }
            "Type" if typ.is_empty() => typ = v.to_string(),
            "NoDisplay" => no_display = v.eq_ignore_ascii_case("true"),
            "Hidden" => hidden = v.eq_ignore_ascii_case("true"),
            _ => {}
        }
    }

    if typ != "Application" || no_display || hidden {
        return None;
    }
    if name.is_empty() || exec.is_empty() {
        return None;
    }
    // Keywords are ;-separated per spec; fold GenericName into the same
    // lowercased search blob ("browser" → Firefox).
    let mut blob = keywords.replace(';', " ");
    if !generic.is_empty() {
        blob.push(' ');
        blob.push_str(&generic);
    }
    Some(App {
        name_lc: name.to_lowercase(),
        keywords: blob.to_lowercase(),
        name,
        icon,
        exec,
        terminal,
    })
}
