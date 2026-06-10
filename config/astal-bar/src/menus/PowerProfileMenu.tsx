import { bind } from "astal"
import { Gtk } from "astal/gtk3"
import AstalBattery from "gi://AstalBattery"
import { PERF_ICONS } from "../const/icons"
import { MENU } from "../const/menu"
import {
  cpuFrac,
  cpuTemp,
  cpuUsage,
  memFrac,
  memText,
  tempFrac,
} from "../services/metrics"
import {
  activeProfile,
  perfMode,
  setPerfMode,
  type PerfMode,
} from "../services/powerProfile"
import { Bar } from "../ui/Bar"
import { Row } from "../ui/Row"
import { Section } from "../ui/Section"
import { MenuWindow } from "./MenuWindow"

const LABEL = {
  "power-saver": "Power Saver",
  balanced: "Balanced",
  performance: "Performance",
} as const

// Full-scale for the power bar (whole-system draw rarely exceeds this).
const POWER_FULL_W = 30

export function PowerProfileMenu() {
  // Selecting a mode leaves the menu open (click outside / Esc to dismiss).
  const item = (mode: PerfMode, name: string, status?: any) =>
    Row({
      icon: PERF_ICONS[mode],
      name,
      klass: mode === "auto" ? undefined : `perf-${mode}`,
      status,
      active: bind(perfMode).as((cur) => cur === mode),
      onClicked: () => setPerfMode(mode),
    })
  const metric = (
    name: string,
    value: any,
    frac: any,
    visible: any = true,
  ) => (
    <box className="metric" vertical spacing={7} visible={visible}>
      <box>
        <label label={name} hexpand halign={Gtk.Align.START} />
        <label className="metric-val" label={value} halign={Gtk.Align.END} />
      </box>
      {Bar({ value: frac })}
    </box>
  )
  // Live discharge power; only meaningful (and shown) while on battery.
  const bat = AstalBattery.get_default()
  const onBattery = bind(bat, "state").as(
    (s) => s === AstalBattery.State.DISCHARGING,
  )
  const powerText = bind(bat, "energyRate").as((w) => `${w.toFixed(1)} W`)
  const powerFrac = bind(bat, "energyRate").as((w) =>
    Math.min(1, w / POWER_FULL_W),
  )
  return MenuWindow({
    name: MENU.perf,
    klass: "perf",
    child: (
      <box vertical>
        {Section(
          "Performance mode",
          <box vertical>
            {item(
              "auto",
              "Automatic",
              bind(activeProfile).as((p) => `Using ${LABEL[p]}`),
            )}
            {item("performance", LABEL.performance)}
            {item("balanced", LABEL.balanced)}
            {item("power-saver", LABEL["power-saver"])}
          </box>,
        )}
        {Section(
          "System",
          <box vertical spacing={8}>
            {metric("CPU", bind(cpuUsage).as((v) => `${v}%`), cpuFrac)}
            {metric("Memory", bind(memText), memFrac)}
            {metric("Temperature", bind(cpuTemp).as((v) => `${v}°C`), tempFrac)}
            {metric("Power", powerText, powerFrac, onBattery)}
          </box>,
        )}
      </box>
    ),
  })
}
