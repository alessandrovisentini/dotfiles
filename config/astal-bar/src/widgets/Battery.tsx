import { Variable, bind } from "astal"
import AstalBattery from "gi://AstalBattery"
import { batteryIcon } from "../utils/icons"
import { pct } from "../utils/shell"

function timeText(secs: number): string {
  if (secs <= 0) return ""
  const h = Math.floor(secs / 3600)
  const m = Math.round((secs % 3600) / 60)
  return h > 0 ? `${h}h ${m}m` : `${m}m`
}

export function Battery() {
  const bat = AstalBattery.get_default()
  const cls = Variable.derive(
    [bind(bat, "percentage"), bind(bat, "charging")],
    (p: number, charging: boolean) => {
      const level = p <= 0.15 ? "critical" : p <= 0.25 ? "warning" : "normal"
      return `chip battery ${level}${charging ? " charging" : ""}`
    },
  )
  const icon = Variable.derive(
    [bind(bat, "percentage"), bind(bat, "charging")],
    (p: number, charging: boolean) => batteryIcon(p, charging),
  )
  const tip = Variable.derive(
    [bind(bat, "charging"), bind(bat, "timeToFull"), bind(bat, "timeToEmpty")],
    (charging: boolean, ttf: number, tte: number) => {
      const t = timeText(charging ? ttf : tte)
      if (!t) return charging ? "Charging" : "On battery"
      return charging ? `Full in ${t}` : `${t} remaining`
    },
  )
  return (
    <box
      className={bind(cls)}
      visible={bind(bat, "isPresent")}
      tooltipText={bind(tip)}
    >
      <label className="module-icon" label={bind(icon)} />
      <label label={bind(bat, "percentage").as(pct)} />
    </box>
  )
}
