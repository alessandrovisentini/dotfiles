import type { MenuName } from "../types/menu"

export const MENU: Record<MenuName, string> = {
  power: "menu-power",
  network: "menu-network",
  bluetooth: "menu-bluetooth",
  volume: "menu-volume",
  brightness: "menu-brightness",
  perf: "menu-perf",
}

export const MENU_NAMES = Object.values(MENU)
