import { Icon } from "../const/icons"
import { closeAllMenus } from "../services/menu"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"

export function Osk() {
  return (
    <button
      className="bar-button"
      onClicked={tap(() => {
        closeAllMenus()
        sh(["osk-toggle"])
      })}
      tooltipText="On-screen keyboard"
    >
      <label className="bar-icon" label={Icon.osk} />
    </button>
  )
}
