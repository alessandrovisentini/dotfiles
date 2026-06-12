import { Variable, bind } from "astal"
import AstalBattery from "gi://AstalBattery"
import { MENU } from "../const/menu"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"
import { batteryIcon } from "../utils/icons"
import { own } from "../utils/reactive"
import { dur, pct } from "../utils/shell"

export function Battery() {
  const bat = AstalBattery.get_default()
  const cls = Variable.derive(
    [bind(bat, "percentage"), bind(bat, "charging")],
    (p: number, charging: boolean) => {
      const level = p <= 0.15 ? "critical" : p <= 0.25 ? "warning" : "normal"
      return `bar-button battery ${level}${charging ? " charging" : ""}`
    },
  )
  const icon = Variable.derive(
    [bind(bat, "percentage"), bind(bat, "charging")],
    (p: number, charging: boolean) => batteryIcon(p, charging),
  )
  const tip = Variable.derive(
    [bind(bat, "charging"), bind(bat, "timeToFull"), bind(bat, "timeToEmpty")],
    (charging: boolean, ttf: number, tte: number) => {
      const t = dur(charging ? ttf : tte)
      if (!t) return charging ? "Charging" : "On battery"
      return charging ? `Full in ${t}` : `${t} remaining`
    },
  )
  return (
    <button
      className={bind(cls)}
      visible={bind(bat, "isPresent")}
      tooltipText={bind(tip)}
      onClicked={tap((self: any) => toggleMenu(MENU.battery, self))}
      setup={own(cls, icon, tip)}
    >
      <box>
        <label className="module-icon" label={bind(icon)} />
        <label label={bind(bat, "percentage").as(pct)} />
      </box>
    </button>
  )
}
