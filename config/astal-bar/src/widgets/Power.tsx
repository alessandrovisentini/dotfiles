import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Power() {
  return (
    <button
      className="bar-button state-power"
      onClicked={tap((self) => toggleMenu(MENU.power, self))}
      tooltipText="Power menu"
    >
      <label className="bar-icon" label={Icon.power} />
    </button>
  )
}
