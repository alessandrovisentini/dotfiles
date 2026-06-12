//! Tablet-friendly app-grid launcher (GTK3 + gtk-layer-shell).
//! GTK3 because GTK4 layer-shell surfaces drop wl_touch events on
//! wlroots compositors.

mod apps;
mod config;
mod daemon;
mod icons;
mod style;
mod ui;

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use gtk::prelude::*;

use crate::config::ICON_DECODE_BATCH;
use crate::ui::{AppsRef, PendingIcons};

fn main() {
    daemon::set_process_name();

    // --daemon: stay alive hidden so later invocations are an instant SIGUSR1 show.
    let args: Vec<String> = std::env::args().collect();
    let daemon_mode = args.iter().any(|a| a == "--daemon");

    if let Some(pid) = daemon::existing_instance() {
        // The boot-time prewarm must not pop the existing window open.
        if !daemon_mode {
            daemon::show(pid);
        }
        return;
    }

    gtk::init().expect("gtk init failed");
    style::apply();

    if let Some(settings) = gtk::Settings::default() {
        settings.set_gtk_cursor_blink(false);
    }

    // Pin the icon theme from gsettings so we don't need an XSETTINGS
    // daemon. set_custom_theme asserts (and no-ops) on the screen singleton,
    // so pinning requires a standalone IconTheme.
    let icon_theme = match icons::configured_icon_theme() {
        Some(name) => {
            let t = gtk::IconTheme::new();
            t.set_custom_theme(Some(&name));
            t
        }
        None => gtk::IconTheme::default().unwrap_or_else(gtk::IconTheme::new),
    };

    let apps_data: AppsRef = Rc::new(RefCell::new(apps::collect_apps()));
    let pending: PendingIcons = Rc::new(RefCell::new(Vec::new()));
    // True while a decoder idle source is alive, so a rescan that lands
    // mid-decode doesn't arm a second one draining the same queue.
    let decoding: Rc<Cell<bool>> = Rc::new(Cell::new(false));

    let (win, flow) = ui::build_window(apps_data.clone(), pending.clone());

    // Hide instead of quitting so the daemon survives close.
    {
        let w = win.clone();
        win.connect_delete_event(move |_, _| {
            w.hide();
            glib::Propagation::Stop
        });
    }

    // Realize the surface once, then SIGUSR1 toggles visibility cheaply.
    win.show_all();
    if daemon_mode {
        win.hide();
    }

    arm_icon_decoder(pending.clone(), icon_theme.clone(), decoding.clone());

    {
        let w = win.clone();
        let flow = flow.clone();
        let apps_data = apps_data.clone();
        let pending = pending.clone();
        let icon_theme = icon_theme.clone();
        let decoding = decoding.clone();
        glib::unix_signal_add_local(libc::SIGUSR1, move || {
            // A second grid-toggle invocation closes the grid.
            if w.is_visible() {
                w.hide();
            } else {
                // Re-scan .desktop files so newly-installed apps appear.
                if ui::refresh(&flow, &apps_data, &pending) {
                    arm_icon_decoder(
                        pending.clone(),
                        icon_theme.clone(),
                        decoding.clone(),
                    );
                }
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

    gtk::main();
}

// Lazy icon decode; decoding all icons up front would stall first paint.
// Re-armed after each rescan because the idle source breaks when the
// queue empties.
fn arm_icon_decoder(
    pending: PendingIcons,
    icon_theme: gtk::IconTheme,
    decoding: Rc<Cell<bool>>,
) {
    if decoding.get() {
        return;
    }
    decoding.set(true);
    let flag = decoding.clone();
    glib::idle_add_local(move || {
        let mut q = pending.borrow_mut();
        for _ in 0..ICON_DECODE_BATCH {
            match q.pop() {
                Some((img, icon_name)) => {
                    if let Some(pix) = icons::load_icon_pixbuf(
                        &icon_name,
                        config::TILE_ICON_PX,
                        &icon_theme,
                    ) {
                        img.set_from_pixbuf(Some(&pix));
                    }
                }
                None => {
                    flag.set(false);
                    return glib::ControlFlow::Break;
                }
            }
        }
        glib::ControlFlow::Continue
    });
}
