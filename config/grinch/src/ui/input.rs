use std::cell::RefCell;
use std::rc::Rc;
use std::time::Duration;

use gtk::prelude::*;

use crate::apps::{launch_app, App};
use crate::config::{FLASH_MS, SWIPE_THRESHOLD_PX_PER_S};

use super::nav::{
    best_matching_child, child_matches, flow_columns, matching_children,
    scroll_child_into_view, APP_IDX_KEY,
};

pub type AppsRef = Rc<RefCell<Vec<App>>>;
// The lowercased query, written once per change. The filter func reads this
// instead of re-fetching + lowercasing the entry text per tile per keystroke.
pub type QueryRef = Rc<RefCell<String>>;

pub fn wire_search(
    flow: &gtk::FlowBox,
    search: &gtk::SearchEntry,
    apps: AppsRef,
    query: QueryRef,
) {
    // FlowBox filter: hide tiles that don't match the query (name prefix/
    // substring/fuzzy subsequence, or Keywords/GenericName).
    {
        let apps_f = apps.clone();
        let query_f = query.clone();
        flow.set_filter_func(Some(Box::new(move |child| {
            let q = query_f.borrow();
            if q.is_empty() {
                return true;
            }
            child_matches(child, &apps_f.borrow(), &q)
        })));
    }

    {
        let flow_s = flow.clone();
        let search_s = search.clone();
        let apps_s = apps;
        let query_s = query;
        search.connect_search_changed(move |_| {
            *query_s.borrow_mut() = search_s.text().to_string().to_lowercase();
            flow_s.invalidate_filter();
            // Pin the Enter target to the best match; don't steal focus
            // from the entry (touch typing keeps OSK up).
            let q = query_s.borrow();
            match best_matching_child(&flow_s, &apps_s.borrow(), &q) {
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

    // Draw a static caret because the entry stays unfocused.
    search.connect_local("draw", true, |args| {
        let widget = args[0].get::<gtk::Widget>().unwrap();
        let cr = args[1].get::<gtk::cairo::Context>().unwrap();
        let entry = match widget.downcast_ref::<gtk::Entry>() {
            Some(e) => e,
            None => return Some(false.to_value()),
        };
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
}

// Blue flash for FLASH_MS, then launch + hide.
pub fn wire_activate(
    flow: &gtk::FlowBox,
    win: &gtk::Window,
    search: &gtk::SearchEntry,
    apps: AppsRef,
) {
    let apps_a = apps;
    let win_a = win.clone();
    let search_a = search.clone();
    flow.connect_child_activated(move |_, child| {
        child.style_context().add_class("activated");
        let idx_ptr: Option<std::ptr::NonNull<usize>> =
            unsafe { child.data::<usize>(APP_IDX_KEY) };
        let app = match idx_ptr {
            Some(p) => unsafe { apps_a.borrow()[*p.as_ref()].clone() },
            None => return,
        };
        let win_l = win_a.clone();
        let search_l = search_a.clone();
        let child_l = child.clone();
        glib::timeout_add_local_once(Duration::from_millis(FLASH_MS), move || {
            launch_app(&app);
            search_l.set_text("");
            child_l.style_context().remove_class("activated");
            win_l.hide();
        });
    });
}

pub fn wire_keys(
    win: &gtk::Window,
    flow: &gtk::FlowBox,
    search: &gtk::SearchEntry,
    scroll: &gtk::ScrolledWindow,
    apps: AppsRef,
    query: QueryRef,
) {
    let flow_k = flow.clone();
    let win_k = win.clone();
    let search_k = search.clone();
    let apps_k = apps;
    let query_k = query;
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
            // Activate the selection if it still matches, else the best
            // match. No match → swallow Enter so we don't launch a stale
            // tile.
            let q = query_k.borrow();
            let apps_b = apps_k.borrow();
            let target = flow_k
                .selected_children()
                .into_iter()
                .find(|c| child_matches(c, &apps_b, &q))
                .or_else(|| best_matching_child(&flow_k, &apps_b, &q));
            if let Some(c) = target {
                flow_k.emit_by_name::<()>("child-activated", &[&c]);
            }
            return glib::Propagation::Stop;
        }

        // Move the grid selection manually so arrows work while the
        // entry holds focus (touch typing keeps the OSK up).
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
            let q = query_k.borrow();
            let matches = matching_children(&flow_k, &apps_k.borrow(), &q);
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

        // Route typing into the filter so search works from anywhere.
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

// Touch flick hides the window.
pub fn wire_swipe(win: &gtk::Window) {
    let swipe = gtk::GestureSwipe::new(win);
    swipe.set_touch_only(true);
    let w = win.clone();
    swipe.connect_swipe(move |_, vx, vy| {
        if (vx * vx + vy * vy).sqrt() > SWIPE_THRESHOLD_PX_PER_S {
            w.hide();
        }
    });
    // Anchor the gesture in the window so it isn't dropped.
    unsafe { win.set_data("close-swipe", swipe) };
}

// Each show resets the filter and focuses the first tile.
pub fn wire_show_reset(
    win: &gtk::Window,
    flow: &gtk::FlowBox,
    search: &gtk::SearchEntry,
    apps: AppsRef,
    query: QueryRef,
) {
    let search_m = search.clone();
    let flow_m = flow.clone();
    let apps_m = apps;
    let query_m = query;
    win.connect_map(move |_| {
        // Reset the cache directly: SearchEntry's search-changed signal is
        // debounced, but the filter must be correct on this frame.
        query_m.borrow_mut().clear();
        search_m.set_text("");
        flow_m.invalidate_filter();
        if let Some(fc) = best_matching_child(&flow_m, &apps_m.borrow(), "") {
            flow_m.select_child(&fc);
            fc.grab_focus();
        }
    });
}
