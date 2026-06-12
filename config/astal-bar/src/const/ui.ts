// Shared layout constants.

// Inset menus below the bar so the click-catcher doesn't cover it.
export const BAR_HEIGHT = 40

// Minimum spin time for a scan button after a click.
export const SCAN_GRACE_MS = 1200

// BlueZ discovery runs until explicitly stopped, so bound each scan to a
// window and call stop_discovery() afterwards — otherwise `adapter.discovering`
// stays true forever and the scan spinner never stops.
export const BT_DISCOVERY_MS = 15000
