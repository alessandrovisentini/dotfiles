import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import { closeAllMenus } from "../services/menu"
import type { MenuWindowProps } from "../types/ui"

// Inset the menu so the click-catcher doesn't cover the bar.
const BAR_HEIGHT = 40

export function MenuWindow(opts: MenuWindowProps) {
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
  const side = opts.side ?? "right"
  return (
    <window
      name={opts.name}
      namespace={opts.name}
      className={`Menu ${opts.klass ?? ""}`}
      application={App}
      visible={false}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      marginTop={BAR_HEIGHT}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      // EXCLUSIVE so the menu can receive Escape.
      keymode={Astal.Keymode.EXCLUSIVE}
      onKeyPressEvent={(_self: any, event: any) => {
        const [ok, keyval] = event.get_keyval()
        if (ok && keyval === Gdk.KEY_Escape) {
          closeAllMenus()
          return true
        }
        return false
      }}
    >
      <eventbox
        hexpand
        vexpand
        onButtonPressEvent={() => {
          closeAllMenus()
          return true
        }}
      >
        <box
          hexpand
          vexpand
          halign={side === "left" ? Gtk.Align.START : Gtk.Align.END}
          valign={Gtk.Align.START}
        >
          <eventbox onButtonPressEvent={() => true}>
            <box className="menu-card" vertical>
              {opts.child}
            </box>
          </eventbox>
        </box>
      </eventbox>
    </window>
  )
}
