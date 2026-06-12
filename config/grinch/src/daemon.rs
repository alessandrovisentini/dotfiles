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

/// PID of another running grinch, or None if we're alone.
pub fn existing_instance() -> Option<i32> {
    let me = std::process::id() as i32;
    let out = Command::new("pgrep").args(["-x", "grinch"]).output().ok()?;
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .filter_map(|l| l.trim().parse::<i32>().ok())
        .find(|&pid| pid != me)
}

/// Ask a running grinch to show its window.
pub fn show(pid: i32) {
    unsafe { libc::kill(pid, libc::SIGUSR1) };
}
