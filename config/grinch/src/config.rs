pub const TILE_ICON_PX: i32 = 72;
pub const FALLBACK_ICON: &str = "application-x-executable";

// Visible-tile flash before the launched app appears.
pub const FLASH_MS: u64 = 150;

// ~400 px/s ≈ a deliberate flick.
pub const SWIPE_THRESHOLD_PX_PER_S: f64 = 400.0;

// Decoding all icons up front would stall first paint.
pub const ICON_DECODE_BATCH: usize = 6;

pub const MIN_COLS: u32 = 4;
pub const MAX_COLS: u32 = 10;

// wrapGAppsHook3 renames the binary; reset comm so `pgrep -x grinch` works.
pub const PROC_NAME: &[u8] = b"grinch\0";
