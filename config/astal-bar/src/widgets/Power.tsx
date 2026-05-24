import { Icon } from "../enums/icons"
import { MENU } from "../enums/menu"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Power() {
  return (
    <button
      className="bar-button accent-icon"
      onClicked={tap(() => toggleMenu(MENU.power))}
      tooltipText="Power menu"
    >
      <label className="bar-icon" label={Icon.power} />
    </button>
  )
}
