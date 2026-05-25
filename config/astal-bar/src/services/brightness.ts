// No Astal lib for backlight. Sysfs `changed` events are flaky on some
// kernels so we run both a Gio.FileMonitor (instant when it fires) and a
// short poll as a safety net. The monitor reference is held at module scope
// to keep GJS from GC'ing the listener.
import { Variable } from "astal"
import { execAsync } from "astal/process"
import Gio from "gi://Gio"
import { sh } from "../utils/shell"

export const hasBacklight = Variable(false)
export const brightness = Variable(0)

let maxBri = 0
execAsync(["brightnessctl", "max"])
  .then((out) => {
    maxBri = Number(out) || 0
    hasBacklight.set(maxBri > 0)
  })
  .catch(() => {})

async function refresh() {
  if (!maxBri) return
  try {
    const cur = Number(await execAsync(["brightnessctl", "get"]))
    if (Number.isFinite(cur)) brightness.set(Math.round((cur / maxBri) * 100))
  } catch {}
}

refresh()
brightness.poll(400, async () => {
  if (!maxBri) return 0
  try {
    const cur = Number(await execAsync(["brightnessctl", "get"]))
    return Number.isFinite(cur) ? Math.round((cur / maxBri) * 100) : brightness.get()
  } catch {
    return brightness.get()
  }
})

let monitor: Gio.FileMonitor | null = null
function watchSysfs() {
  try {
    const dir = Gio.File.new_for_path("/sys/class/backlight")
    const e = dir.enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const info = e.next_file(null)
    if (!info) return
    const file = Gio.File.new_for_path(
      `/sys/class/backlight/${info.get_name()}/brightness`,
    )
    monitor = file.monitor(Gio.FileMonitorFlags.NONE, null)
    monitor.connect("changed", () => refresh())
  } catch {}
}
watchSysfs()

export function setBrightness(value: number) {
  const v = Math.max(1, Math.min(100, Math.round(value)))
  brightness.set(v)
  sh(["brightnessctl", "set", `${v}%`])
}
