import { App } from "astal/gtk3"
import { MENU_NAMES } from "../enums/menu"

export function closeAllMenus(except?: string) {
  for (const name of MENU_NAMES) {
    if (name === except) continue
    const w = App.get_window(name)
    if (w) w.visible = false
  }
}

export function toggleMenu(name: string) {
  const w = App.get_window(name)
  const willShow = !w?.visible
  closeAllMenus(name)
  if (w) w.visible = willShow
}
