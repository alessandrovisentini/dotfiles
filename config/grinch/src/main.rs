//! Tablet-friendly app-grid launcher (GTK3 + gtk-layer-shell).
//!
//! GTK3, not GTK4: GTK4 layer-shell surfaces drop wl_touch events on
//! Hyprland.

use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::rc::Rc;
use std::time::Duration;

use gdk_pixbuf::{InterpType, Pixbuf};
use gio::prelude::*;
use gtk::prelude::*;
use gtk_layer_shell as lshell;

const TILE_ICON_PX: i32 = 72;
const FALLBACK_ICON: &str = "application-x-executable";

const ICON_THEME_ORDER: &[&str] = &["Papirus", "Adwaita", "hicolor", "breeze"];
const ICON_SIZE_ORDER: &[&str] = &[
    "scalable", "512x512", "256x256", "128x128", "96x96", "72x72",
    "64x64", "48x48", "32x32",
];

/// Signal an already-running grinch to show and return its PID, or
/// None if this process is the singleton. Prevents stacked windows.
fn signal_existing_grinch() -> Option<i32> {
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

const CSS: &[u8] = b"
window { background-color: rgba(28, 28, 28, 0.96); }
.top-bar { margin: 24px 24px 0 24px; }
entry {
    padding: 14px 18px;
    font-size: 18px;
    border-radius: 12px;
    background: #1d1d1d;
    color: #ffffff;
    border: 2px solid #4a4a4d;
}
entry:focus { border-color: #ffffff; }
.close-btn {
    padding: 0 16px;
    margin-left: 12px;
    border-radius: 12px;
    background: #1d1d1d;
    color: #ffffff;
    border: 2px solid #4a4a4d;
    font-size: 20px;
    font-weight: bold;
}
.close-btn:hover { background: #4a4a4d; }
.close-btn:active { background: #3584e4; }
flowbox { padding: 16px; }
flowboxchild { padding: 6px; }
flowboxchild .tile {
    padding: 14px 6px;
    border-radius: 14px;
    background: transparent;
    transition: background-color 100ms ease;
}
flowboxchild:selected .tile,
flowboxchild:hover .tile { background: #4a4a4d; }
flowboxchild.activated .tile { background: #3584e4; }
flowboxchild .tile label { color: #ffffff; font-size: 13px; }
";

#[derive(Clone)]
struct App {
    name: String,
    icon: String,
    exec: String,
    terminal: bool,
}

fn main() {
    // wrapGAppsHook3 renames the binary to `.grinch-wrapped`, so
    // /proc/PID/comm (15-char cap) breaks `pgrep -x grinch`. Reset it
    // so the singleton check and grid.sh's detection work.
    unsafe {
        let name = b"grinch\0";
        libc::prctl(
            libc::PR_SET_NAME,
            name.as_ptr() as libc::c_ulong,
            0u64,
            0u64,
            0u64,
        );
    }

    // --daemon: stay alive with a hidden window so later invocations
    // just send SIGUSR1 (instant show vs. cold GTK init each time).
    let args: Vec<String> = std::env::args().collect();
    let daemon = args.iter().any(|a| a == "--daemon");

    // Single-instance guard: signal the running instance and exit.
    if let Some(_pid) = signal_existing_grinch() {
        return;
    }

    gtk::init().expect("gtk init failed");
    apply_css();

    let icon_index = build_icon_index();
    let apps = collect_apps();

    let (win, pending) = build_window(apps);

    // Close button / Escape / launch: hide window instead of quitting
    // so the process stays alive for the next invocation.
    {
        let w = win.clone();
        win.connect_delete_event(move |_, _| {
            w.hide();
            glib::Propagation::Stop
        });
    }

    // show_all once so the widget tree + layer-shell surface are
    // realized, then hide. SIGUSR1 then just toggles visibility (one
    // commit) instead of re-running the full map each time.
    win.show_all();
    if daemon {
        win.hide();
    }

    {
        let w = win.clone();
        glib::unix_signal_add_local(libc::SIGUSR1, move || {
            // show() on the window only, not show_all on the subtree
            // — children stay marked visible from the initial paint.
            if !w.is_visible() {
                w.show();
            }
            glib::ControlFlow::Continue
        });
    }
    {
        let w = win.clone();
        glib::unix_signal_add_local(libc::SIGUSR2, move || {
            w.hide();
            glib::ControlFlow::Continue
        });
    }
    glib::unix_signal_add_local(libc::SIGTERM, || {
        gtk::main_quit();
        glib::ControlFlow::Break
    });

    // Lazy icon decode via idle callbacks; decoding all icons up front
    // would stall the launcher's first paint.
    let icon_index = Rc::new(icon_index);
    let pending = Rc::new(std::cell::RefCell::new(pending));
    glib::idle_add_local(move || {
        let mut q = pending.borrow_mut();
        for _ in 0..6 {
            match q.pop() {
                Some((img, icon_name)) => {
                    if let Some(pix) =
                        load_icon_pixbuf(&icon_name, TILE_ICON_PX, &icon_index)
                    {
                        img.set_from_pixbuf(Some(&pix));
                    }
                }
                None => return glib::ControlFlow::Break,
            }
        }
        glib::ControlFlow::Continue
    });

    gtk::main();
}

// ---------- CSS ----------

fn apply_css() {
    let provider = gtk::CssProvider::new();
    provider.load_from_data(CSS).expect("css load");
    let screen = gdk::Screen::default().expect("screen");
    gtk::StyleContext::add_provider_for_screen(
        &screen,
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_USER,
    );
}

// ---------- App discovery ----------

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

fn collect_apps() -> Vec<App> {
    let mut seen_files = std::collections::HashSet::new();
    let mut seen_names = std::collections::HashSet::new();
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
        // First-write-wins: skip locale-suffixed duplicates like Name[de]=…
        let k = k.trim();
        let v = v.trim();
        match k {
            "Name" if name.is_empty() => name = v.to_string(),
            "Icon" if icon.is_empty() => icon = v.to_string(),
            "Exec" if exec.is_empty() => exec = v.to_string(),
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
    Some(App { name, icon, exec, terminal })
}

// ---------- Icon index ----------

/// Pre-scan all icon-theme apps dirs once. Maps both the .desktop
/// Icon= name and lowercase to an absolute file path.
fn build_icon_index() -> HashMap<String, PathBuf> {
    let mut idx: HashMap<String, PathBuf> = HashMap::new();
    for data in xdg_data_dirs() {
        let icons_root = data.join("icons");
        for theme in ICON_THEME_ORDER {
            let theme_dir = icons_root.join(theme);
            if !theme_dir.is_dir() {
                continue;
            }
            for size in ICON_SIZE_ORDER {
                let apps_dir = theme_dir.join(size).join("apps");
                let entries = match fs::read_dir(&apps_dir) {
                    Ok(e) => e,
                    Err(_) => continue,
                };
                for ent in entries.flatten() {
                    let path = ent.path();
                    let stem = match path.file_stem().and_then(|s| s.to_str()) {
                        Some(s) => s.to_string(),
                        None => continue,
                    };
                    // First match per stem wins (theme priority order)
                    idx.entry(stem.clone()).or_insert_with(|| path.clone());
                    let lc = stem.to_lowercase();
                    if lc != stem {
                        idx.entry(lc).or_insert(path);
                    }
                }
            }
        }
        // /share/pixmaps fallback
        let pixmaps = data.join("pixmaps");
        if let Ok(entries) = fs::read_dir(&pixmaps) {
            for ent in entries.flatten() {
                let path = ent.path();
                if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                    idx.entry(stem.to_string()).or_insert_with(|| path.clone());
                }
            }
        }
    }
    idx
}

fn load_icon_pixbuf(
    icon: &str,
    size: i32,
    idx: &HashMap<String, PathBuf>,
) -> Option<Pixbuf> {
    if icon.is_empty() {
        return None;
    }
    let path = if Path::new(icon).is_absolute() && Path::new(icon).exists() {
        PathBuf::from(icon)
    } else if let Some(p) = idx.get(icon) {
        p.clone()
    } else if let Some(p) = idx.get(&icon.to_lowercase()) {
        p.clone()
    } else {
        return None;
    };
    let pix = Pixbuf::from_file_at_size(&path, size, size).ok()?;
    if pix.width() == size && pix.height() == size {
        Some(pix)
    } else {
        pix.scale_simple(size, size, InterpType::Bilinear)
    }
}

// ---------- UI ----------

fn build_window(apps: Vec<App>) -> (gtk::Window, Vec<(gtk::Image, String)>) {
    let win = gtk::Window::new(gtk::WindowType::Toplevel);
    win.set_title("Apps");

    lshell::init_for_window(&win);
    // Named layer namespace for hyprctl layers / window rules.
    lshell::set_namespace(&win, "grinch");
    lshell::set_layer(&win, lshell::Layer::Overlay);
    for edge in [
        lshell::Edge::Top,
        lshell::Edge::Bottom,
        lshell::Edge::Left,
        lshell::Edge::Right,
    ] {
        lshell::set_anchor(&win, edge, true);
    }
    lshell::set_keyboard_mode(&win, lshell::KeyboardMode::OnDemand);
    lshell::set_exclusive_zone(&win, 0);

    let outer = gtk::Box::new(gtk::Orientation::Vertical, 0);
    win.add(&outer);

    // Top bar: search entry stretching, X button on the right.
    let top_bar = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    top_bar.style_context().add_class("top-bar");
    outer.pack_start(&top_bar, false, false, 0);

    let search = gtk::SearchEntry::new();
    search.set_placeholder_text(Some("Search apps…"));
    search.set_hexpand(true);
    top_bar.pack_start(&search, true, true, 0);

    let close_btn = gtk::Button::with_label("✕");
    close_btn.style_context().add_class("close-btn");
    close_btn.set_focus_on_click(false);
    {
        let w = win.clone();
        close_btn.connect_clicked(move |_| w.hide());
    }
    top_bar.pack_start(&close_btn, false, false, 0);

    let scroll = gtk::ScrolledWindow::new(
        gtk::Adjustment::NONE,
        gtk::Adjustment::NONE,
    );
    scroll.set_policy(gtk::PolicyType::Never, gtk::PolicyType::Automatic);
    outer.pack_start(&scroll, true, true, 0);

    let flow = gtk::FlowBox::new();
    flow.set_valign(gtk::Align::Start);
    flow.set_min_children_per_line(4);
    flow.set_max_children_per_line(10);
    flow.set_homogeneous(true);
    flow.set_selection_mode(gtk::SelectionMode::Single);
    scroll.add(&flow);

    // Each child stores its index into `apps` (read back by filter +
    // activation). Icons are collected for lazy decode after show.
    let apps = Rc::new(apps);
    let mut pending_icons: Vec<(gtk::Image, String)> = Vec::new();
    for (idx, app) in apps.iter().enumerate() {
        let (child, img) = build_tile(app);
        unsafe {
            child.set_data::<usize>("app_idx", idx);
        }
        flow.insert(&child, -1);
        if !app.icon.is_empty() {
            pending_icons.push((img, app.icon.clone()));
        }
    }
    // Pop in display order: reverse so .pop() drains top-first.
    pending_icons.reverse();

    // Search filter
    {
        let apps_f = apps.clone();
        let search_f = search.clone();
        flow.set_filter_func(Some(Box::new(move |child| {
            let q = search_f.text().to_string().to_lowercase();
            if q.is_empty() {
                return true;
            }
            let idx_ptr: Option<std::ptr::NonNull<usize>> =
                unsafe { child.data::<usize>("app_idx") };
            match idx_ptr {
                Some(p) => unsafe {
                    apps_f[*p.as_ref()].name.to_lowercase().contains(&q)
                },
                None => true,
            }
        })));
        let flow_s = flow.clone();
        search.connect_search_changed(move |_| flow_s.invalidate_filter());
    }

    // Activation: blue flash for 150ms, then launch + hide window.
    // The daemon stays alive for the next invocation.
    {
        let apps_a = apps.clone();
        let win_a = win.clone();
        let search_a = search.clone();
        flow.connect_child_activated(move |_, child| {
            child.style_context().add_class("activated");
            let idx_ptr: Option<std::ptr::NonNull<usize>> =
                unsafe { child.data::<usize>("app_idx") };
            let app = match idx_ptr {
                Some(p) => unsafe { apps_a[*p.as_ref()].clone() },
                None => return,
            };
            let win_l = win_a.clone();
            let search_l = search_a.clone();
            let child_l = child.clone();
            glib::timeout_add_local_once(
                Duration::from_millis(150),
                move || {
                    launch_app(&app);
                    // Reset state so next invocation comes up clean.
                    search_l.set_text("");
                    child_l.style_context().remove_class("activated");
                    win_l.hide();
                },
            );
        });
    }

    // Esc → hide, Enter → activate first visible
    {
        let flow_k = flow.clone();
        let win_k = win.clone();
        win.connect_key_press_event(move |_, ev| {
            let key = ev.keyval();
            if key == gdk::keys::constants::Escape {
                win_k.hide();
                return glib::Propagation::Stop;
            }
            if key == gdk::keys::constants::Return
                || key == gdk::keys::constants::KP_Enter
            {
                let sel = flow_k.selected_children();
                if let Some(c) = sel.first() {
                    flow_k.emit_by_name::<()>("child-activated", &[c]);
                    return glib::Propagation::Stop;
                }
                for c in flow_k.children() {
                    if c.is_child_visible() {
                        if let Ok(fc) = c.downcast::<gtk::FlowBoxChild>() {
                            flow_k.emit_by_name::<()>(
                                "child-activated",
                                &[&fc],
                            );
                            return glib::Propagation::Stop;
                        }
                    }
                }
            }
            glib::Propagation::Proceed
        });
    }

    // Single-finger flick hides the window.
    {
        let swipe = gtk::GestureSwipe::new(&win);
        swipe.set_touch_only(true);
        let w = win.clone();
        swipe.connect_swipe(move |_, vx, vy| {
            // px/s; ~400 ≈ a deliberate flick, not an accidental drag.
            if (vx * vx + vy * vy).sqrt() > 400.0 {
                w.hide();
            }
        });
        // Keep the gesture owned by the window or it'd be dropped here.
        unsafe { win.set_data("close-swipe", swipe) };
    }

    search.grab_focus();
    (win, pending_icons)
}

fn build_tile(app: &App) -> (gtk::FlowBoxChild, gtk::Image) {
    let tile = gtk::Box::new(gtk::Orientation::Vertical, 4);
    tile.style_context().add_class("tile");

    // Placeholder icon; the lazy pass overwrites it once decoded.
    let img = gtk::Image::new();
    img.set_pixel_size(TILE_ICON_PX);
    img.set_from_icon_name(Some(FALLBACK_ICON), gtk::IconSize::Dialog);
    img.set_halign(gtk::Align::Center);
    tile.pack_start(&img, false, false, 0);

    let lbl = gtk::Label::new(Some(&app.name));
    lbl.set_halign(gtk::Align::Center);
    lbl.set_max_width_chars(14);
    lbl.set_lines(2);
    lbl.set_line_wrap(true);
    lbl.set_justify(gtk::Justification::Center);
    tile.pack_start(&lbl, false, false, 0);

    let child = gtk::FlowBoxChild::new();
    child.add(&tile);
    (child, img)
}

// ---------- Launch ----------

fn launch_app(app: &App) {
    // Strip .desktop field codes (%f, %u, %F, %U, %i, %c, %k …) per spec.
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
