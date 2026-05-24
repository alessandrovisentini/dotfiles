use gtk::prelude::*;

use crate::apps::App;

// Single source of truth for the per-child app index key.
pub const APP_IDX_KEY: &str = "app_idx";

fn child_app_idx(child: &gtk::FlowBoxChild) -> Option<usize> {
    let p: Option<std::ptr::NonNull<usize>> =
        unsafe { child.data::<usize>(APP_IDX_KEY) };
    p.map(|p| unsafe { *p.as_ref() })
}

/// `query` must already be lowercased. We re-run the predicate manually
/// because FlowBox's filter visibility isn't exposed on the child.
pub fn child_matches(child: &gtk::FlowBoxChild, apps: &[App], query: &str) -> bool {
    if query.is_empty() {
        return true;
    }
    match child_app_idx(child) {
        Some(i) => apps[i].name.to_lowercase().contains(query),
        None => false,
    }
}

/// First matching tile in reading order. `query` must already be lowercased.
pub fn first_matching_child(
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

/// All matching tiles in reading order. `query` must already be lowercased.
pub fn matching_children(
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

/// Column count from the current layout. Valid only after the grid is laid out.
pub fn flow_columns(matches: &[gtk::FlowBoxChild]) -> usize {
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

/// Scroll just enough to bring `child` into the viewport.
pub fn scroll_child_into_view(scroll: &gtk::ScrolledWindow, child: &gtk::FlowBoxChild) {
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
