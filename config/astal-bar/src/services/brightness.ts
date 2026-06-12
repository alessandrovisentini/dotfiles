// No Astal lib for backlight, so drive sysfs directly. Reads go through
// GLib (no subprocess), which makes the safety-net poll behind the flaky
// sysfs file monitor essentially free. Writes still go through brightnessctl
// for its udev permission handling. The monitor reference is held at module
// scope to keep GJS from GC'ing the listener.
import { Variable } from "astal"
import { execAsync } from "astal/process"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import { readFile } from "../utils/sysfs"

export const hasBacklight = Variable(false)
export const brightness = Variable(0) // %

let briPath: string | null = null
let maxBri = 0

function readNum(path: string): number {
  const txt = readFile(path)
  return txt === null ? NaN : Number(txt.trim())
}

// First device under /sys/class/backlight (mirrors brightnessctl's default).
function findDevice() {
  try {
    const base = "/sys/class/backlight"
    const e = Gio.File.new_for_path(base).enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const info = e.next_file(null)
    if (!info) return
    const dir = `${base}/${info.get_name()}`
    const max = readNum(`${dir}/max_brightness`)
    if (!Number.isFinite(max) || max <= 0) return
    briPath = `${dir}/brightness`
    maxBri = max
    hasBacklight.set(true)
  } catch {}
}
findDevice()

// Block external refreshes briefly after a user write so the poll/monitor
// echo can't yank the slider back mid-drag.
let holdUntil = 0
const nowMs = () => GLib.get_monotonic_time() / 1000

function currentPct(): number {
  const cur = readNum(briPath!)
  return Number.isFinite(cur)
    ? Math.round((cur / maxBri) * 100)
    : brightness.get()
}

let monitor: Gio.FileMonitor | null = null
if (briPath) {
  brightness.set(currentPct())

  // inotify on sysfs attributes is unreliable across kernels; keep the
  // monitor for where it works (instant), with the poll as the net.
  try {
    monitor = Gio.File.new_for_path(briPath).monitor(
      Gio.FileMonitorFlags.NONE,
      null,
    )
    monitor.connect("changed", () => {
      if (nowMs() >= holdUntil) brightness.set(currentPct())
    })
  } catch {}

  brightness.poll(1000, (prev) => (nowMs() < holdUntil ? prev : currentPct()))
}

// Writes are serialized: one brightnessctl in flight, latest target wins.
// Drag events arrive faster than the spawn round-trip and intermediate
// values are pointless to apply.
let inFlight = false
let pending: number | null = null

async function write(v: number) {
  if (inFlight) {
    pending = v
    return
  }
  inFlight = true
  for (;;) {
    try {
      await execAsync(["brightnessctl", "-q", "set", `${v}%`])
    } catch {}
    if (pending === null) break
    v = pending
    pending = null
  }
  inFlight = false
}

export function setBrightness(value: number) {
  const v = Math.max(1, Math.min(100, Math.round(value)))
  holdUntil = nowMs() + 800
  brightness.set(v)
  write(v)
}
