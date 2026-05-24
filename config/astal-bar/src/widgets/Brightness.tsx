import { bind } from "astal"
import { Icon } from "../enums/icons"
import { MENU } from "../enums/menu"
import { brightness, hasBacklight } from "../services/brightness"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Brightness() {
  return (
    <button
      className="bar-button"
      visible={bind(hasBacklight)}
      onClicked={tap(() => toggleMenu(MENU.brightness))}
      tooltipText="Brightness"
    >
      <box>
        <label className="module-icon" label={Icon.brightness} />
        <label label={bind(brightness).as((v) => `${v}%`)} />
      </box>
    </button>
  )
}
