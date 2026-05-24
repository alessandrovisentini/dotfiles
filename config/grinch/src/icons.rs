use std::path::Path;

use gdk_pixbuf::{InterpType, Pixbuf};
use gio::prelude::*;
use gtk::prelude::*;

/// Read the configured icon theme from gsettings. The schema lookup
/// guards against GLib aborting when the schema is absent.
pub fn configured_icon_theme() -> Option<String> {
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

/// Resolve a .desktop Icon= value to a pixbuf (themed name or absolute path).
pub fn load_icon_pixbuf(
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
