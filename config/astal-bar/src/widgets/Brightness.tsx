import { bind } from "astal"
import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { brightness, hasBacklight } from "../services/brightness"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Brightness() {
  return (
    <button
      className="bar-button state-bright"
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
