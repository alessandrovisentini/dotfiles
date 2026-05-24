use gtk::prelude::*;

const CSS: &str = include_str!("style.css");

pub fn apply() {
    let provider = gtk::CssProvider::new();
    provider.load_from_data(CSS.as_bytes()).expect("css load");
    let screen = gdk::Screen::default().expect("screen");
    gtk::StyleContext::add_provider_for_screen(
        &screen,
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_USER,
    );
}
