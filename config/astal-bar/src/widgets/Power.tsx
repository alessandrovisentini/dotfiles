import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Power() {
  return (
    <button
      className="bar-button state-power"
      onClicked={tap(() => toggleMenu(MENU.power))}
      tooltipText="Power menu"
    >
      <label className="bar-icon" label={Icon.power} />
    </button>
  )
}
