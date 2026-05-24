//! Tablet-friendly app-grid launcher (GTK3 + gtk-layer-shell).
//! GTK3 because GTK4 layer-shell surfaces drop wl_touch events on
//! wlroots compositors.

mod apps;
mod config;
mod daemon;
mod icons;
mod style;
mod ui;

use std::rc::Rc;

use gtk::prelude::*;

use crate::config::ICON_DECODE_BATCH;

fn main() {
    daemon::set_process_name();

    // --daemon: stay alive hidden so later invocations are an instant SIGUSR1 show.
    let args: Vec<String> = std::env::args().collect();
    let daemon_mode = args.iter().any(|a| a == "--daemon");

    if daemon::signal_existing_grinch().is_some() {
        return;
    }

    gtk::init().expect("gtk init failed");
    style::apply();

    if let Some(settings) = gtk::Settings::default() {
        settings.set_gtk_cursor_blink(false);
    }

    // Pin the icon theme so we don't need an XSETTINGS daemon.
    let icon_theme = gtk::IconTheme::default().unwrap_or_else(gtk::IconTheme::new);
    if let Some(theme) = icons::configured_icon_theme() {
        icon_theme.set_custom_theme(Some(&theme));
    }

    let (win, pending) = ui::build_window(apps::collect_apps());

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

    {
        let w = win.clone();
        glib::unix_signal_add_local(libc::SIGUSR1, move || {
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

    // Lazy icon decode; decoding all icons up front would stall first paint.
    let pending = Rc::new(std::cell::RefCell::new(pending));
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
                None => return glib::ControlFlow::Break,
            }
        }
        glib::ControlFlow::Continue
    });

    gtk::main();
}
