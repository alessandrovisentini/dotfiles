// Lightweight system metrics for the performance menu. Sampled from /proc and
// sysfs only while the menu is open (start/stopMetrics, driven by visibility),
// so nothing polls in the background.
import { Variable } from "astal"
import Gio from "gi://Gio"
import GLib from "gi://GLib"

export const cpuUsage = Variable(0) // %
export const memText = Variable("—") // used / total
export const cpuTemp = Variable(0) // °C

// Current bar fill levels, normalized 0..1.
export const cpuFrac = Variable(0)
export const memFrac = Variable(0)
export const tempFrac = Variable(0)

const clamp = (v: number) => Math.max(0, Math.min(1, v))

function readText(path: string): string | null {
  try {
    const [ok, data] = GLib.file_get_contents(path)
    return ok ? new TextDecoder().decode(data) : null
  } catch {
    return null
  }
}

// "used / total UNIT", both scaled to the total's unit.
function pair(usedBytes: number, totalBytes: number): string {
  const units = ["B", "KiB", "MiB", "GiB", "TiB"]
  let i = 0
  let total = totalBytes
  while (total >= 1024 && i < units.length - 1) {
    total /= 1024
    i++
  }
  const used = usedBytes / 1024 ** i
  const dec = i >= 3 ? 1 : 0
  return `${used.toFixed(dec)} / ${total.toFixed(dec)} ${units[i]}`
}

let prevIdle = 0
let prevTotal = 0
function sampleCpu(): number {
  const txt = readText("/proc/stat")
  if (!txt) return cpuUsage.get()
  const cols = txt.split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
  if (cols.length < 4) return cpuUsage.get()
  const idle = cols[3] + (cols[4] || 0) // idle + iowait
  const total = cols.reduce((a, b) => a + b, 0)
  const dIdle = idle - prevIdle
  const dTotal = total - prevTotal
  prevIdle = idle
  prevTotal = total
  if (dTotal <= 0) return cpuUsage.get()
  return Math.round((1 - dIdle / dTotal) * 100)
}

function sampleMem(): { text: string; frac: number } {
  const txt = readText("/proc/meminfo")
  if (!txt) return { text: memText.get(), frac: 0 }
  const field = (k: string) => {
    const m = txt.match(new RegExp(`^${k}:\\s+(\\d+)`, "m"))
    return m ? Number(m[1]) : 0
  }
  const totalKiB = field("MemTotal")
  const availKiB = field("MemAvailable")
  if (!totalKiB) return { text: memText.get(), frac: 0 }
  const used = totalKiB - availKiB
  return { text: pair(used * 1024, totalKiB * 1024), frac: used / totalKiB }
}

// Resolved once: prefer the package sensor, else a CPU/ACPI zone, else zone0.
let tempPath: string | null | undefined
function findTempPath(): string | null {
  try {
    const base = "/sys/class/thermal"
    const e = Gio.File.new_for_path(base).enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const zones: string[] = []
    let info: Gio.FileInfo | null
    while ((info = e.next_file(null))) {
      const n = info.get_name()
      if (n.startsWith("thermal_zone")) zones.push(`${base}/${n}`)
    }
    let fallback: string | null = null
    for (const z of zones) {
      const type = (readText(`${z}/type`) || "").trim()
      if (type === "x86_pkg_temp") return `${z}/temp`
      if (!fallback && /coretemp|acpitz|cpu/i.test(type)) fallback = `${z}/temp`
    }
    return fallback ?? (zones.length ? `${zones[0]}/temp` : null)
  } catch {
    return null
  }
}

function sampleTemp(): number {
  if (tempPath === undefined) tempPath = findTempPath()
  if (!tempPath) return cpuTemp.get()
  const txt = readText(tempPath)
  const milli = txt ? Number(txt.trim()) : NaN
  return Number.isFinite(milli) ? Math.round(milli / 1000) : cpuTemp.get()
}

let timer = 0
function refresh() {
  const cpu = sampleCpu()
  cpuUsage.set(cpu)
  cpuFrac.set(clamp(cpu / 100))

  const mem = sampleMem()
  memText.set(mem.text)
  memFrac.set(clamp(mem.frac))

  const temp = sampleTemp()
  cpuTemp.set(temp)
  // Map a useful CPU range (30–100 °C) onto the bar.
  tempFrac.set(clamp((temp - 30) / 70))
}

export function startMetrics() {
  if (timer) return
  // Keep the CPU baseline across opens so the first sample is a real average
  // (a reset would read 0%).
  refresh()
  timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
    refresh()
    return GLib.SOURCE_CONTINUE
  })
}

export function stopMetrics() {
  if (timer) {
    GLib.source_remove(timer)
    timer = 0
  }
}
