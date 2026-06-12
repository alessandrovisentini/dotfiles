// Nerd-font glyph maps. Single source of truth for icons used by widgets.

export const WIFI_RAMP = {
  off: "󰤯",
  low: "󰤟",
  medium: "󰤢",
  high: "󰤥",
  full: "󰤨",
} as const

export const WIFI_DISABLED = "󰤮"

export const VOLUME_RAMP = {
  mute: "󰝟",
  silent: "󰕿",
  low: "󰖀",
  full: "󰕾",
} as const

export const MIC_ICONS = {
  on: "󰍬",
  off: "󰍭",
} as const

export const BATTERY_RAMP = [
  "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹",
] as const
export const BATTERY_CHARGING = "󰂄"

// Performance-mode menu glyphs (speedometer ramp + an "auto" mark).
export const PERF_ICONS = {
  auto: "󰃨",
  performance: "󰓅",
  balanced: "󰾅",
  "power-saver": "󰾆",
} as const

export const BLUETOOTH_ICONS = {
  connected: "󰂱",
  powered: "󰂯",
  off: "󰂲",
} as const

export const NOTIFICATION_ICONS = {
  dndOn: "󰟎",
  dndOff: "󰂚",
} as const

export const Icon = {
  power: "⏻",
  brightness: "󰃠",
  osk: "󰌌",
  wired: "󰈀",
  vpn: "󰦝",
  scan: "󰑐",
  settings: "󰒓",
  add: "󰐕",
  // PowerMenu tiles
  lock: "󰌾",
  suspend: "󰒲",
  logout: "󰍃",
  restart: "󰜉",
  shutdown: "⏻",
} as const
