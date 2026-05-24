use gtk::prelude::*;

use crate::apps::App;
use crate::config::{FALLBACK_ICON, TILE_ICON_PX};

pub fn build_tile(app: &App) -> (gtk::FlowBoxChild, gtk::Image) {
    let tile = gtk::Box::new(gtk::Orientation::Vertical, 4);
    tile.style_context().add_class("tile");

    // Placeholder; the lazy pass overwrites it once decoded.
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
