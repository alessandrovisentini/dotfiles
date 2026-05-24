import { Variable, bind } from "astal"
import { Gdk, Gtk } from "astal/gtk3"
import AstalTray from "gi://AstalTray"

export function SysTray() {
  const tray = AstalTray.get_default()
  return (
    <box className="tray">
      {bind(tray, "items").as((items) =>
        items.map((item) => {
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
                  if (item.isMenu) return showMenu(self)
                  item.activate(x, y)
                  return true
                }
                return false
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
