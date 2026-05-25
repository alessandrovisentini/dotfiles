import { Variable, bind } from "astal"
import { execAsync, subprocess } from "astal/process"
import { NOTIFICATION_ICONS } from "../const/icons"
import { closeAllMenus } from "../services/menu"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"

// swaync handles the notification panel and toasts. We just subscribe to its
// waybar feed so the bell reflects DND + has-notifications state.
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

export function Notifications() {
  const cls = Variable.derive([bind(dnd)], (d) =>
    `bar-button ${d ? "state-dnd" : "state-notif"}`,
  )
  return (
    <button
      className={bind(cls)}
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
      <label
        className="bar-icon"
        label={bind(dnd).as((d) =>
          d ? NOTIFICATION_ICONS.dndOn : NOTIFICATION_ICONS.dndOff,
        )}
      />
    </button>
  )
}
