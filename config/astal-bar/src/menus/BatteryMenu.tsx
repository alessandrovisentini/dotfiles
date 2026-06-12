import { Variable, bind } from "astal"
import { Gtk } from "astal/gtk3"
import AstalBattery from "gi://AstalBattery"
import { MENU } from "../const/menu"
import {
  startChargeHistory,
  stopChargeHistory,
} from "../services/batteryHistory"
import { ChargeGraph } from "../ui/ChargeGraph"
import { Section } from "../ui/Section"
import { batteryIcon } from "../utils/icons"
import { own } from "../utils/reactive"
import { dur, pct } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

const S = AstalBattery.State

export function BatteryMenu() {
  const bat = AstalBattery.get_default()
  const iconCls = Variable.derive(
    [bind(bat, "percentage"), bind(bat, "charging")],
    (p: number, charging: boolean) => {
      const level = p <= 0.15 ? "critical" : p <= 0.25 ? "warning" : "normal"
      return `batt-icon ${charging ? "normal" : level}`
    },
  )
  const icon = Variable.derive(
    [bind(bat, "percentage"), bind(bat, "charging")],
    (p: number, charging: boolean) => batteryIcon(p, charging),
  )
  const status = Variable.derive(
    [
      bind(bat, "state"),
      bind(bat, "timeToFull"),
      bind(bat, "timeToEmpty"),
      bind(bat, "energyRate"),
    ],
    (st: AstalBattery.State, ttf: number, tte: number, rate: number) => {
      if (st === S.FULLY_CHARGED) return "Fully charged"
      if (st === S.PENDING_CHARGE) return "Plugged in, not charging"
      if (st === S.CHARGING) {
        const t = dur(ttf)
        return t ? `Charging · full in ${t}` : "Charging"
      }
      const t = dur(tte)
      const w = rate > 0.5 ? ` · ${rate.toFixed(1)} W` : ""
      return (t ? `${t} remaining` : "On battery") + w
    },
  )
  const win = MenuWindow({
    name: MENU.battery,
    klass: "batt",
    child: (
      <box vertical setup={own(iconCls, icon, status)}>
        {Section(
          "Battery",
          <box className="batt-head">
            <label className={bind(iconCls)} label={bind(icon)} />
            <box vertical hexpand valign={Gtk.Align.CENTER}>
              <label
                className="batt-pct"
                label={bind(bat, "percentage").as(pct)}
                halign={Gtk.Align.START}
              />
              <label
                className="subtle"
                label={bind(status)}
                halign={Gtk.Align.START}
              />
            </box>
          </box>,
        )}
        {Section(
          "Last 24 hours",
          <box vertical>
            {ChargeGraph()}
            <box className="legend" spacing={16}>
              <box spacing={6}>
                <label className="legend-swatch level" label="●" />
                <label className="subtle" label="Battery level" />
              </box>
              <box spacing={6}>
                <label className="legend-swatch power" label="󰚥" />
                <label className="subtle" label="Connected to power" />
              </box>
            </box>
          </box>,
        )}
      </box>
    ),
  })

  // Read the UPower history only while this menu is open.
  win.connect("notify::visible", () =>
    win.visible ? startChargeHistory() : stopChargeHistory(),
  )

  return win
}
