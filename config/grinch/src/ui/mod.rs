mod input;
mod nav;
mod tile;

use std::rc::Rc;

use gtk::prelude::*;
use gtk_layer_shell as lshell;

use crate::apps::App;
use crate::config::{MAX_COLS, MIN_COLS};

use nav::APP_IDX_KEY;
use tile::build_tile;

pub fn build_window(apps: Vec<App>) -> (gtk::Window, Vec<(gtk::Image, String)>) {
    let win = gtk::Window::new(gtk::WindowType::Toplevel);
    win.set_title("Apps");

    init_layer_shell(&win);

    let outer = gtk::Box::new(gtk::Orientation::Vertical, 0);
    win.add(&outer);

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
    flow.set_min_children_per_line(MIN_COLS);
    flow.set_max_children_per_line(MAX_COLS);
    flow.set_homogeneous(true);
    flow.set_selection_mode(gtk::SelectionMode::Single);
    scroll.add(&flow);

    // Each child stores its index into `apps`; icons queued for lazy decode.
    let apps = Rc::new(apps);
    let mut pending_icons: Vec<(gtk::Image, String)> = Vec::new();
    for (idx, app) in apps.iter().enumerate() {
        let (child, img) = build_tile(app);
        unsafe {
            child.set_data::<usize>(APP_IDX_KEY, idx);
        }
        flow.insert(&child, -1);
        if !app.icon.is_empty() {
            pending_icons.push((img, app.icon.clone()));
        }
    }
    // Reverse so .pop() drains top-first.
    pending_icons.reverse();

    input::wire_search(&flow, &search, apps.clone());
    input::wire_activate(&flow, &win, &search, apps.clone());
    input::wire_keys(&win, &flow, &search, &scroll, apps.clone());
    input::wire_swipe(&win);
    input::wire_show_reset(&win, &flow, &search, apps);

    (win, pending_icons)
}

fn init_layer_shell(win: &gtk::Window) {
    lshell::init_for_window(win);
    lshell::set_namespace(win, "grinch");
    lshell::set_layer(win, lshell::Layer::Overlay);
    for edge in [
        lshell::Edge::Top,
        lshell::Edge::Bottom,
        lshell::Edge::Left,
        lshell::Edge::Right,
    ] {
        lshell::set_anchor(win, edge, true);
    }
    lshell::set_keyboard_mode(win, lshell::KeyboardMode::OnDemand);
    lshell::set_exclusive_zone(win, 0);
}
