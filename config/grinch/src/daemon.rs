use std::process::Command;

use crate::config::PROC_NAME;

pub fn set_process_name() {
    unsafe {
        libc::prctl(
            libc::PR_SET_NAME,
            PROC_NAME.as_ptr() as libc::c_ulong,
            0u64,
            0u64,
            0u64,
        );
    }
}

/// Signal a running grinch to show. Returns its PID, or None if we're alone.
pub fn signal_existing_grinch() -> Option<i32> {
    let me = std::process::id() as i32;
    let out = Command::new("pgrep").args(["-x", "grinch"]).output().ok()?;
    let stdout = String::from_utf8_lossy(&out.stdout);
    for line in stdout.lines() {
        if let Ok(pid) = line.trim().parse::<i32>() {
            if pid != me {
                unsafe { libc::kill(pid, libc::SIGUSR1) };
                return Some(pid);
            }
        }
    }
    None
}
