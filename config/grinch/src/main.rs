//! Tablet-friendly app-grid launcher (GTK3 + gtk-layer-shell).
//!
//! GTK3, not GTK4: GTK4 layer-shell surfaces drop wl_touch events on
//! Hyprland.

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
flowboxchild:hover .tile { background: #4a4a4d; }
flowboxchild:selected .tile {
    background: #4a4a4d;
    box-shadow: inset 0 0 0 2px #3584e4;
}
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

    // Static (non-blinking) text caret, rofi-style.
    if let Some(settings) = gtk::Settings::default() {
        settings.set_gtk_cursor_blink(false);
    }

    // Resolve icons through GtkIconTheme — the same resolver GNOME and
    // the notification daemon use — so grinch's icons match the rest of
    // the system (correct theme, Inherits chain, scalable/sized dirs,
    // pixmaps fallback). Pin it to the configured theme so we don't
    // depend on an XSETTINGS daemon being present under Hyprland.
    let icon_theme = gtk::IconTheme::default()
        .unwrap_or_else(gtk::IconTheme::new);
    if let Some(theme) = configured_icon_theme() {
        icon_theme.set_custom_theme(Some(&theme));
    }

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
    let pending = Rc::new(std::cell::RefCell::new(pending));
    glib::idle_add_local(move || {
        let mut q = pending.borrow_mut();
        for _ in 0..6 {
            match q.pop() {
                Some((img, icon_name)) => {
                    if let Some(pix) =
                        load_icon_pixbuf(&icon_name, TILE_ICON_PX, &icon_theme)
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

// ---------- Icons ----------

/// The user's configured GTK/GNOME icon theme, read from gsettings
/// (`org.gnome.desktop.interface icon-theme`) — the same source GNOME
/// apps use. Returns None if the schema isn't installed or the key is
/// unset. The schema-source lookup guards against GLib aborting when
/// the GNOME schemas are absent (gio::Settings::new aborts otherwise).
fn configured_icon_theme() -> Option<String> {
    const SCHEMA: &str = "org.gnome.desktop.interface";
    let schema = gio::SettingsSchemaSource::default()?.lookup(SCHEMA, true)?;
    if !schema.has_key("icon-theme") {
        return None;
    }
    let theme = gio::Settings::new(SCHEMA).string("icon-theme").to_string();
    if theme.is_empty() {
        None
    } else {
        Some(theme)
    }
}

/// Resolve a .desktop Icon= value to a pixbuf via GtkIconTheme (themed
/// names) or directly (absolute paths). Using GtkIconTheme means we
/// honor the active theme's full inheritance chain exactly like every
/// other app, instead of guessing at directories ourselves.
fn load_icon_pixbuf(
    icon: &str,
    size: i32,
    theme: &gtk::IconTheme,
) -> Option<Pixbuf> {
    if icon.is_empty() {
        return None;
    }
    if Path::new(icon).is_absolute() {
        let pix = Pixbuf::from_file_at_size(icon, size, size).ok()?;
        return if pix.width() == size && pix.height() == size {
            Some(pix)
        } else {
            pix.scale_simple(size, size, InterpType::Bilinear)
        };
    }
    theme
        .load_icon(icon, size, gtk::IconLookupFlags::FORCE_SIZE)
        .ok()
        .flatten()
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
        let search_s = search.clone();
        let apps_s = apps.clone();
        search.connect_search_changed(move |_| {
            flow_s.invalidate_filter();
            // Keep the Enter target pinned to the first match and visibly
            // selected. Only pull keyboard focus into the grid when the
            // entry isn't focused — touch typing keeps focus (and the OSK)
            // on the entry itself. With no match, drop the selection so a
            // stale tile can't be activated.
            let q = search_s.text().to_string().to_lowercase();
            match first_matching_child(&flow_s, &apps_s, &q) {
                Some(fc) => {
                    flow_s.select_child(&fc);
                    if !search_s.has_focus() {
                        fc.grab_focus();
                    }
                }
                None => flow_s.unselect_all(),
            }
        });
    }

    // Static, non-blinking caret. The entry stays unfocused (the grid
    // owns focus), so GTK paints no caret of its own — draw one at the
    // end of the text, rofi-style, so it's clear typing lands here.
    search.connect_local("draw", true, |args| {
        let widget = args[0].get::<gtk::Widget>().unwrap();
        let cr = args[1].get::<gtk::cairo::Context>().unwrap();
        let entry = match widget.downcast_ref::<gtk::Entry>() {
            Some(e) => e,
            None => return Some(false.to_value()),
        };
        // When focused (e.g. tapped on touch) GTK draws the real caret.
        if entry.has_focus() {
            return Some(false.to_value());
        }
        let layout = match entry.layout() {
            Some(l) => l,
            None => return Some(false.to_value()),
        };
        let (off_x, off_y) = entry.layout_offsets();
        let idx = entry.text().as_str().len() as i32;
        let caret_x = off_x + layout.index_to_pos(idx).x() / gtk::pango::SCALE;
        let (_, line_h) = layout.pixel_size();
        let caret_h = if line_h > 0 {
            line_h
        } else {
            (entry.allocated_height() as f64 * 0.5) as i32
        };
        cr.set_source_rgb(1.0, 1.0, 1.0);
        cr.rectangle(caret_x as f64 + 0.5, off_y as f64, 2.0, caret_h as f64);
        let _ = cr.fill();
        Some(false.to_value())
    });

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
        let search_k = search.clone();
        let apps_k = apps.clone();
        let scroll_k = scroll.clone();
        win.connect_key_press_event(move |_, ev| {
            let key = ev.keyval();
            if key == gdk::keys::constants::Escape {
                win_k.hide();
                return glib::Propagation::Stop;
            }
            if key == gdk::keys::constants::Return
                || key == gdk::keys::constants::KP_Enter
            {
                // Activate the current selection only if it still matches
                // the query, else the first match. With no match, swallow
                // Enter so grinch stays open instead of launching a stale
                // tile (the selection survives filtering — see child_matches).
                let q = search_k.text().to_string().to_lowercase();
                let target = flow_k
                    .selected_children()
                    .into_iter()
                    .find(|c| child_matches(c, &apps_k, &q))
                    .or_else(|| first_matching_child(&flow_k, &apps_k, &q));
                if let Some(c) = target {
                    flow_k.emit_by_name::<()>("child-activated", &[&c]);
                }
                return glib::Propagation::Stop;
            }

            // Arrow keys move the grid selection — by hand, so they work
            // even while the search entry holds focus (touch typing), where
            // they'd otherwise just move the text caret. Focus stays on the
            // entry when it has it, keeping the on-screen keyboard up; Enter
            // activates whatever ends up selected.
            let arrow = if key == gdk::keys::constants::Left {
                Some((-1i32, false))
            } else if key == gdk::keys::constants::Right {
                Some((1, false))
            } else if key == gdk::keys::constants::Up {
                Some((-1, true))
            } else if key == gdk::keys::constants::Down {
                Some((1, true))
            } else {
                None
            };
            if let Some((step, vertical)) = arrow {
                let q = search_k.text().to_string().to_lowercase();
                let matches = matching_children(&flow_k, &apps_k, &q);
                if !matches.is_empty() {
                    let sel = flow_k.selected_children();
                    let cur = sel
                        .first()
                        .and_then(|s| matches.iter().position(|c| c == s))
                        .unwrap_or(0) as i32;
                    let delta = if vertical {
                        step * flow_columns(&matches) as i32
                    } else {
                        step
                    };
                    let new = (cur + delta).clamp(0, matches.len() as i32 - 1);
                    let target = &matches[new as usize];
                    flow_k.select_child(target);
                    scroll_child_into_view(&scroll_k, target);
                    if !search_k.has_focus() {
                        target.grab_focus();
                    }
                }
                return glib::Propagation::Stop;
            }

            // Route typing into the filter by hand so search works from
            // anywhere. When the entry *does* hold focus (tapped on touch),
            // let it edit itself for everything else (Home/End, etc.).
            if search_k.has_focus() {
                return glib::Propagation::Proceed;
            }
            let mods = ev.state();
            let ctrl_alt = mods.contains(gdk::ModifierType::CONTROL_MASK)
                || mods.contains(gdk::ModifierType::MOD1_MASK);
            if !ctrl_alt {
                if key == gdk::keys::constants::BackSpace {
                    let mut t = search_k.text().to_string();
                    if t.pop().is_some() {
                        search_k.set_text(&t);
                    }
                    return glib::Propagation::Stop;
                }
                if let Some(ch) = key.to_unicode() {
                    if !ch.is_control() {
                        let mut t = search_k.text().to_string();
                        t.push(ch);
                        search_k.set_text(&t);
                        return glib::Propagation::Stop;
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

    // Every show (incl. the daemon's SIGUSR1 re-show) comes up clean:
    // clear the stale filter, then highlight + focus the first tile so
    // Enter launches it and arrows step from there (not from the entry).
    {
        let search_m = search.clone();
        let flow_m = flow.clone();
        let apps_m = apps.clone();
        win.connect_map(move |_| {
            search_m.set_text("");
            flow_m.invalidate_filter();
            // Empty query → first tile overall is the Enter target.
            if let Some(fc) = first_matching_child(&flow_m, &apps_m, "") {
                flow_m.select_child(&fc);
                fc.grab_focus();
            }
        });
    }

    (win, pending_icons)
}

/// Does this tile pass the current search filter? `query` must already
/// be lowercased. GTK3's FlowBox filter keeps visibility in a private
/// field and never touches the widget's child-visible flag, so
/// `is_child_visible()` can't be trusted — we re-run the predicate the
/// filter_func uses (app name contains query).
fn child_matches(child: &gtk::FlowBoxChild, apps: &[App], query: &str) -> bool {
    if query.is_empty() {
        return true;
    }
    let idx_ptr: Option<std::ptr::NonNull<usize>> =
        unsafe { child.data::<usize>("app_idx") };
    match idx_ptr {
        Some(p) => unsafe { apps[*p.as_ref()].name.to_lowercase().contains(query) },
        None => false,
    }
}

/// First tile matching the current query (top-left in reading order) —
/// the implicit Enter target. `query` must already be lowercased.
fn first_matching_child(
    flow: &gtk::FlowBox,
    apps: &[App],
    query: &str,
) -> Option<gtk::FlowBoxChild> {
    for c in flow.children() {
        if let Ok(fc) = c.downcast::<gtk::FlowBoxChild>() {
            if child_matches(&fc, apps, query) {
                return Some(fc);
            }
        }
    }
    None
}

/// All tiles matching the current query, in reading order. `query` must
/// already be lowercased.
fn matching_children(
    flow: &gtk::FlowBox,
    apps: &[App],
    query: &str,
) -> Vec<gtk::FlowBoxChild> {
    flow.children()
        .into_iter()
        .filter_map(|c| c.downcast::<gtk::FlowBoxChild>().ok())
        .filter(|c| child_matches(c, apps, query))
        .collect()
}

/// Tiles in the top row of the current layout — the column count used to
/// step the selection vertically. Reads widget allocations, so it's only
/// meaningful once the grid has been laid out.
fn flow_columns(matches: &[gtk::FlowBoxChild]) -> usize {
    match matches.first() {
        None => 1,
        Some(first) => {
            let top = first.allocation().y();
            matches
                .iter()
                .filter(|c| c.allocation().y() == top)
                .count()
                .max(1)
        }
    }
}

/// Scroll just enough to bring `child` fully into the viewport. We move
/// the selection by hand (to keep entry focus + the OSK), so the grid
/// won't auto-scroll for us the way it would on focus changes.
fn scroll_child_into_view(scroll: &gtk::ScrolledWindow, child: &gtk::FlowBoxChild) {
    let alloc = child.allocation();
    let adj = scroll.vadjustment();
    let top = alloc.y() as f64;
    let bottom = top + alloc.height() as f64;
    let (val, page) = (adj.value(), adj.page_size());
    if top < val {
        adj.set_value(top);
    } else if bottom > val + page {
        adj.set_value((bottom - page).max(0.0));
    }
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
