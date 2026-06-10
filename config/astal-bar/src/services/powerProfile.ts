// Performance-mode selector backing the battery menu. The bar owns the
// governor/turbo/platform_profile knobs (set via the `power-profile` helper);
// TLP handles the rest. In "auto" the profile follows the power source.
import { Variable, bind } from "astal"
import AstalBattery from "gi://AstalBattery"
import GLib from "gi://GLib"
import { sh } from "../utils/shell"

export type PerfMode = "auto" | "power-saver" | "balanced" | "performance"
type Profile = Exclude<PerfMode, "auto">

const MODES: readonly string[] = ["auto", "power-saver", "balanced", "performance"]
const stateFile = `${GLib.get_user_state_dir()}/astal-bar/power-mode`

function load(): PerfMode {
  try {
    const [ok, data] = GLib.file_get_contents(stateFile)
    if (ok) {
      const s = new TextDecoder().decode(data).trim()
      if (MODES.includes(s)) return s as PerfMode
    }
  } catch {}
  return "auto"
}

function save(mode: PerfMode) {
  try {
    GLib.mkdir_with_parents(GLib.path_get_dirname(stateFile), 0o755)
    GLib.file_set_contents(stateFile, new TextEncoder().encode(mode))
  } catch {}
}

const bat = AstalBattery.get_default()
// UPower "charging" is false at 100% on AC, so key off the discharge state.
const onBattery = () => bat.state === AstalBattery.State.DISCHARGING
const profileFor = (mode: PerfMode): Profile =>
  mode !== "auto" ? mode : onBattery() ? "power-saver" : "balanced"

export const perfMode = Variable<PerfMode>(load())

// Effective profile (for the menu's "Automatic" sub-label).
export const activeProfile = Variable.derive(
  [bind(perfMode), bind(bat, "state")],
  (mode: PerfMode) => profileFor(mode),
)

function apply() {
  sh(["power-profile", profileFor(perfMode.get())])
}

export function setPerfMode(mode: PerfMode) {
  perfMode.set(mode)
  save(mode)
  apply()
}

// Re-apply on AC<->battery transitions while following the hardware.
bat.connect("notify::state", () => {
  if (perfMode.get() === "auto") apply()
})

apply()
