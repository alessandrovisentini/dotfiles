use std::env;
use std::process::Command;

use super::App;

pub fn launch_app(app: &App) {
    // Strip .desktop field codes per spec.
    let argv: Vec<String> = app
        .exec
        .split_whitespace()
        .filter(|tok| !tok.starts_with('%'))
        .map(String::from)
        .collect();
    if argv.is_empty() {
        return;
    }
    let mut cmd = if app.terminal {
        let term = env::var("TERMINAL").unwrap_or_else(|_| "alacritty".into());
        let mut c = Command::new(term);
        c.arg("-e");
        for a in &argv {
            c.arg(a);
        }
        c
    } else {
        let mut c = Command::new(&argv[0]);
        for a in &argv[1..] {
            c.arg(a);
        }
        c
    };
    let _ = cmd.spawn();
}
