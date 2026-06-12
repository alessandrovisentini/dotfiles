import { Variable, bind } from "astal"
import { Gtk } from "astal/gtk3"
import { execAsync, subprocess } from "astal/process"
import { NOTIFICATION_ICONS } from "../const/icons"
import { closeAllMenus } from "../services/menu"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"

// swaync handles the notification panel and toasts. We just subscribe to its
// waybar feed so the bell reflects DND + pending-notification state.
const dnd = Variable(false)
const count = Variable(0)

execAsync(["swaync-client", "-D"])
  .then((out) => dnd.set(out.trim() === "true"))
  .catch(() => {})
execAsync(["swaync-client", "-c"])
  .then((out) => count.set(Number(out.trim()) || 0))
  .catch(() => {})

subprocess(
  ["swaync-client", "--subscribe-waybar", "-sw"],
  (line: string) => {
    try {
      const data = JSON.parse(line)
      if (typeof data.class === "string") dnd.set(data.class.includes("dnd"))
      if (typeof data.text === "string") count.set(Number(data.text) || 0)
    } catch {}
  },
  () => {},
)

// Module-level (not per-bar) so hotplugged bars don't leak subscriptions.
// The bell only tints orange while notifications are actually pending; DND
// (magenta) wins over the pending tint.
const bell = Variable.derive([dnd, count], (d: boolean, c: number) => ({
  cls: `bar-button ${d ? "state-dnd" : c > 0 ? "state-notif" : ""}`,
  icon: d ? NOTIFICATION_ICONS.dndOn : NOTIFICATION_ICONS.dndOff,
  badge: c > 0 ? String(c) : "",
}))

export function Notifications() {
  return (
    <button
      className={bind(bell).as((b) => b.cls)}
      tooltipText="Notifications  ·  right-click: Do-Not-Disturb"
      onClicked={tap(() => {
        closeAllMenus()
        sh(["swaync-client", "-t", "-sw"])
      })}
      onButtonPressEvent={(_, event) => {
        const [ok, btn] = event.get_button()
        if (ok && btn === 3) {
          closeAllMenus()
          dnd.set(!dnd.get())
          sh(["swaync-client", "-d"])
          return true
        }
        return false
      }}
    >
      {/* Count badge overlaid on the bell's top-right corner. */}
      <overlay>
        <label
          className="bar-icon"
          label={bind(bell).as((b) => b.icon)}
        />
        <label
          className="notif-count"
          halign={Gtk.Align.END}
          valign={Gtk.Align.START}
          label={bind(bell).as((b) => b.badge)}
          visible={bind(bell).as((b) => b.badge !== "")}
        />
      </overlay>
    </button>
  )
}
