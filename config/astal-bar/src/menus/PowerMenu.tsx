import { Gtk } from "astal/gtk3"
import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { closeAllMenus } from "../services/menu"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

export function PowerMenu() {
  const act = (cmd: string[]) => {
    closeAllMenus()
    sh(cmd)
  }
  const tile = (icon: string, label: string, cmd: string[], danger = false) => (
    <button
      className={danger ? "danger" : ""}
      tooltipText={label}
      onClicked={tap(() => act(cmd))}
    >
      <label className="pwr-icon" label={icon} />
    </button>
  )
  return MenuWindow({
    name: MENU.power,
    side: "left",
    klass: "pwr",
    child: (
      <box className="power-grid" homogeneous halign={Gtk.Align.CENTER}>
        {tile(Icon.lock, "Lock", ["swaylock"])}
        {tile(Icon.suspend, "Suspend", ["systemctl", "suspend"])}
        {tile(Icon.logout, "Log out", ["swaymsg", "exit"])}
        {tile(Icon.restart, "Restart", ["systemctl", "reboot"])}
        {tile(Icon.shutdown, "Shut down", ["systemctl", "poweroff"], true)}
      </box>
    ),
  })
}
