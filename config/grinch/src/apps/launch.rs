use std::env;
use std::os::unix::process::CommandExt;
use std::process::Command;

use super::App;

// Standalone field codes are dropped per the desktop spec (we never pass
// files/URLs); %% unescapes to a literal %.
const FIELD_CODES: &[&str] = &[
    "%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m",
];

/// Split an Exec= value per the desktop spec: arguments separated by
/// whitespace, double quotes group, backslash escapes the next character
/// inside quotes. Naive whitespace splitting mangles entries like
/// `env FOO="a b" prog`.
fn split_exec(exec: &str) -> Vec<String> {
    let mut args = Vec::new();
    let mut cur = String::new();
    let mut started = false;
    let mut in_quotes = false;
    let mut chars = exec.chars();
    while let Some(c) = chars.next() {
        if in_quotes {
            match c {
                '"' => in_quotes = false,
                '\\' => {
                    if let Some(n) = chars.next() {
                        cur.push(n);
                    }
                }
                _ => cur.push(c),
            }
        } else if c == '"' {
            in_quotes = true;
            started = true;
        } else if c.is_whitespace() {
            if started {
                args.push(std::mem::take(&mut cur));
                started = false;
            }
        } else {
            cur.push(c);
            started = true;
        }
    }
    if started {
        args.push(cur);
    }
    args
}

pub fn launch_app(app: &App) {
    let argv: Vec<String> = split_exec(&app.exec)
        .into_iter()
        .filter(|tok| !FIELD_CODES.contains(&tok.as_str()))
        .map(|tok| tok.replace("%%", "%"))
        .collect();
    if argv.is_empty() {
        return;
    }
    let mut cmd = if app.terminal {
        let term = env::var("TERMINAL").unwrap_or_else(|_| "alacritty".into());
        let mut c = Command::new(term);
        c.arg("-e");
        c.args(&argv);
        c
    } else {
        let mut c = Command::new(&argv[0]);
        c.args(&argv[1..]);
        c
    };

    // Double-fork + setsid: the intermediate child exits immediately and the
    // app is reparented to init. Without this every launched app stays a
    // child of the long-lived daemon — a zombie once it exits (nothing ever
    // reaps it) — and dies with the daemon's session.
    unsafe {
        cmd.pre_exec(|| {
            libc::setsid();
            match libc::fork() {
                0 => Ok(()),
                -1 => Err(std::io::Error::last_os_error()),
                _ => libc::_exit(0),
            }
        });
    }
    match cmd.spawn() {
        // Reap the intermediate; it exits right away.
        Ok(mut child) => {
            let _ = child.wait();
        }
        Err(e) => eprintln!("grinch: failed to launch {:?}: {e}", argv[0]),
    }
}

#[cfg(test)]
mod tests {
    use super::split_exec;

    #[test]
    fn plain() {
        assert_eq!(split_exec("firefox --new-window"), ["firefox", "--new-window"]);
    }

    #[test]
    fn quoted_spaces() {
        assert_eq!(
            split_exec(r#"env FOO="a b" prog"#),
            ["env", "FOO=a b", "prog"]
        );
    }

    #[test]
    fn escaped_quote() {
        assert_eq!(split_exec(r#""say \"hi\"""#), [r#"say "hi""#]);
    }

    #[test]
    fn collapses_whitespace() {
        assert_eq!(split_exec("  a   b  "), ["a", "b"]);
    }

    #[test]
    fn empty_quoted_arg() {
        assert_eq!(split_exec(r#"prog "" x"#), ["prog", "", "x"]);
    }
}
