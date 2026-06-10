import { Variable, bind } from "astal"
import { Gdk, Gtk } from "astal/gtk3"
import AstalTray from "gi://AstalTray"
import GLib from "gi://GLib"

// Hold an icon this long to pop its menu instead of left-clicking. Lets a
// touch tap activate while a press-and-hold reaches the menu (e.g. Discord).
const LONG_PRESS_MS = 500

// Items we never want in the tray. nm-applet only runs as our NM secret
// agent; its icon would be a confusing duplicate of the Network widget.
const HIDDEN_TRAY_IDS = new Set(["nm-applet"])

const visibleItems = (items: any[]) =>
  items.filter((item) => !HIDDEN_TRAY_IDS.has(item.id ?? ""))

// True when at least one tray item is visible; consumers gate parent
// containers on this so an empty tray collapses entirely.
export const trayHasItems = bind(AstalTray.get_default(), "items").as(
  (items) => visibleItems(items).length > 0,
)

export function SysTray() {
  const tray = AstalTray.get_default()
  return (
    <box className="tray">
      {bind(tray, "items").as((items) =>
        visibleItems(items).map((item) => {
          // Build a transient Gtk.Menu from the SNI MenuModel.
          const showMenu = (anchor: any) => {
            try {
              item.about_to_show()
              if (!item.menuModel) return false
              const popup = Gtk.Menu.new_from_model(item.menuModel)
              popup.insert_action_group("dbusmenu", item.actionGroup)
              popup.attach_to_widget(anchor, null)
              popup.popup_at_widget(
                anchor,
                Gdk.Gravity.SOUTH,
                Gdk.Gravity.NORTH,
                null,
              )
              return true
            } catch {
              return false
            }
          }
          const leftClick = (anchor: any, x: number, y: number) => {
            if (item.isMenu) return showMenu(anchor)
            item.activate(x, y)
            return true
          }
          // Per-item long-press state. The timer fires the menu mid-hold; a
          // release before it fires cancels and counts as a left click.
          let pressTimer = 0
          let longPressed = false
          const clearTimer = () => {
            if (pressTimer) {
              GLib.source_remove(pressTimer)
              pressTimer = 0
            }
          }
          // Some apps register icons lazily.
          const hasIcon = Variable.derive(
            [bind(item, "gicon"), bind(item, "iconName")],
            (g: any, n: any) => !!g || (typeof n === "string" && n.length > 0),
          )
          return (
            <button
              className="bar-button"
              tooltipMarkup={bind(item, "tooltipMarkup")}
              visible={bind(hasIcon)}
              onButtonPressEvent={(self: any, event: any) => {
                const [okB, btn] = event.get_button()
                if (!okB) return false
                const [okR, rx, ry] = event.get_root_coords()
                const x = okR ? rx : 0
                const y = okR ? ry : 0
                if (btn === 3) return showMenu(self)
                if (btn === 2) {
                  item.secondary_activate(x, y)
                  return true
                }
                if (btn === 1) {
                  longPressed = false
                  clearTimer()
                  pressTimer = GLib.timeout_add(
                    GLib.PRIORITY_DEFAULT,
                    LONG_PRESS_MS,
                    () => {
                      pressTimer = 0
                      longPressed = true
                      showMenu(self)
                      return GLib.SOURCE_REMOVE
                    },
                  )
                  return true
                }
                return false
              }}
              onButtonReleaseEvent={(self: any, event: any) => {
                const [okB, btn] = event.get_button()
                if (!okB || btn !== 1) return false
                clearTimer()
                if (longPressed) {
                  longPressed = false
                  return true
                }
                const [okR, rx, ry] = event.get_root_coords()
                return leftClick(self, okR ? rx : 0, okR ? ry : 0)
              }}
            >
              <icon gicon={bind(item, "gicon")} />
            </button>
          )
        }),
      )}
    </box>
  )
}
