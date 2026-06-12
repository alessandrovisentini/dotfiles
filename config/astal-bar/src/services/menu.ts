import { App, Gdk, Gtk } from "astal/gtk3"
import { MENU_NAMES } from "../const/menu"

export function closeAllMenus(except?: string) {
  for (const name of MENU_NAMES) {
    if (name === except) continue
    const w = App.get_window(name)
    if (w) w.visible = false
  }
}

// Menus are single global windows; without an explicit monitor the
// compositor maps them on the focused output, which on multi-monitor isn't
// necessarily where the user clicked. The anchor widget (the bar button)
// tells us which monitor to show on.
function monitorOf(anchor: Gtk.Widget): Gdk.Monitor | null {
  const gdkwin = anchor.get_window()
  return gdkwin ? anchor.get_display().get_monitor_at_window(gdkwin) : null
}

export function toggleMenu(name: string, anchor?: Gtk.Widget) {
  const w = App.get_window(name)
  const willShow = !w?.visible
  closeAllMenus(name)
  if (!w) return
  if (willShow && anchor) {
    const monitor = monitorOf(anchor)
    if (monitor && (w as any).gdkmonitor !== monitor)
      (w as any).gdkmonitor = monitor
  }
  w.visible = willShow
}
