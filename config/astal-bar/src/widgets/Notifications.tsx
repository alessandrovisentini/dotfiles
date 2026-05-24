import { Variable, bind } from "astal"
import { execAsync } from "astal/process"
import { NOTIFICATION_ICONS } from "../enums/icons"
import { closeAllMenus } from "../services/menu"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"

// Left: toggle swaync panel. Right: toggle DND.
export function Notifications() {
  const dnd = Variable(false).poll(2000, async () => {
    try {
      return (await execAsync(["swaync-client", "-D"])).trim() === "true"
    } catch {
      return false
    }
  })
  return (
    <button
      className="bar-button"
      tooltipText="Notifications  ·  right-click: Do-Not-Disturb"
      onClicked={tap(() => {
        closeAllMenus()
        sh(["swaync-client", "-t", "-sw"])
      })}
      onButtonPressEvent={(_, event) => {
        const [ok, btn] = event.get_button()
        if (ok && btn === 3) {
          closeAllMenus()
          sh(["swaync-client", "-d"])
          dnd.set(!dnd.get())
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
