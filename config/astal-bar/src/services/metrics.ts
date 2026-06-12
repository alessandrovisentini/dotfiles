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

// Integrated GPU (shown whenever a GPU on the root PCI bus is found). VRAM is
// only reported when the driver exposes it (e.g. an integrated amdgpu); Intel
// i915 has no memory usage in sysfs, so its VRAM row stays hidden.
export const igpuPresent = Variable(false)
export const igpuUsage = Variable(0) // %
export const igpuFrac = Variable(0)
export const igpuHasMem = Variable(false)
export const igpuMemText = Variable("—")
export const igpuMemFrac = Variable(0)

// Discrete / eGPU (shown only while present — e.g. an eGPU enclosure is
// connected). amdgpu exposes the full set via sysfs.
export const dgpuPresent = Variable(false)
export const dgpuUsage = Variable(0) // %
export const dgpuFrac = Variable(0)
export const dgpuMemText = Variable("—")
export const dgpuMemFrac = Variable(0)
export const dgpuTemp = Variable(0) // °C
export const dgpuTempFrac = Variable(0)

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

// --- GPUs -----------------------------------------------------------------
// Detected fresh on every refresh so an eGPU connect/disconnect is reflected
// while the menu stays open. Classification is driver-agnostic: a card on the
// root PCI bus (0000:00:*) is integrated, anything else is discrete.
type Gpu = { card: string; device: string; driver: string }

function listDrmCards(): string[] {
  try {
    const base = "/sys/class/drm"
    const e = Gio.File.new_for_path(base).enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const cards: string[] = []
    let info: Gio.FileInfo | null
    while ((info = e.next_file(null))) {
      const n = info.get_name()
      if (/^card\d+$/.test(n)) cards.push(`${base}/${n}`)
    }
    return cards
  } catch {
    return []
  }
}

function uevent(path: string): Record<string, string> {
  const out: Record<string, string> = {}
  const txt = readText(path)
  if (!txt) return out
  for (const line of txt.split("\n")) {
    const i = line.indexOf("=")
    if (i > 0) out[line.slice(0, i)] = line.slice(i + 1).trim()
  }
  return out
}

function detectGpus(): { igpu: Gpu | null; dgpu: Gpu | null } {
  let igpu: Gpu | null = null
  let dgpu: Gpu | null = null
  for (const card of listDrmCards()) {
    const device = `${card}/device`
    const ue = uevent(`${device}/uevent`)
    const driver = ue.DRIVER
    if (!driver) continue
    const gpu: Gpu = { card, device, driver }
    if ((ue.PCI_SLOT_NAME || "").startsWith("0000:00:")) {
      if (!igpu) igpu = gpu
    } else if (!dgpu) {
      dgpu = gpu
    }
  }
  return { igpu, dgpu }
}

// The amdgpu temp/power live in a hwmon subdir whose index isn't stable.
function deviceHwmon(device: string): string | null {
  try {
    const base = `${device}/hwmon`
    const e = Gio.File.new_for_path(base).enumerate_children(
      "standard::name",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    const info = e.next_file(null)
    return info ? `${base}/${info.get_name()}` : null
  } catch {
    return null
  }
}

const numAt = (path: string): number => {
  const txt = readText(path)
  const n = txt ? Number(txt.trim()) : NaN
  return Number.isFinite(n) ? n : NaN
}

// i915 has no overall busy% file; derive it from rc6 (deep-idle) residency.
let prevRc6 = 0
let prevRc6T = 0
function sampleIgpuUtil(g: Gpu): number {
  const busy = numAt(`${g.device}/gpu_busy_percent`)
  if (Number.isFinite(busy)) {
    prevRc6T = 0 // not using rc6 for this driver
    return Math.round(busy)
  }
  const rc6 = numAt(`${g.card}/gt/gt0/rc6_residency_ms`)
  const now = GLib.get_monotonic_time() / 1000 // ms
  let util = igpuUsage.get()
  if (prevRc6T && now > prevRc6T && Number.isFinite(rc6) && rc6 >= prevRc6) {
    util = Math.round(clamp(1 - (rc6 - prevRc6) / (now - prevRc6T)) * 100)
  }
  prevRc6 = rc6
  prevRc6T = now
  return util
}

function sampleIgpu(g: Gpu | null) {
  if (!g) {
    igpuPresent.set(false)
    prevRc6T = 0
    return
  }
  igpuPresent.set(true)
  const util = sampleIgpuUtil(g)
  igpuUsage.set(util)
  igpuFrac.set(clamp(util / 100))

  // Intel i915 reports no memory usage in sysfs, so the VRAM row stays hidden.
  const vramTotal = numAt(`${g.device}/mem_info_vram_total`)
  const vramUsed = numAt(`${g.device}/mem_info_vram_used`)
  if (Number.isFinite(vramTotal) && vramTotal > 0) {
    igpuHasMem.set(true)
    igpuMemText.set(pair(vramUsed, vramTotal))
    igpuMemFrac.set(clamp(vramUsed / vramTotal))
  } else {
    igpuHasMem.set(false)
  }
}

function sampleDgpu(g: Gpu | null) {
  if (!g) {
    dgpuPresent.set(false)
    return
  }
  dgpuPresent.set(true)
  const busy = numAt(`${g.device}/gpu_busy_percent`)
  const util = Number.isFinite(busy) ? Math.round(busy) : dgpuUsage.get()
  dgpuUsage.set(util)
  dgpuFrac.set(clamp(util / 100))

  const vramTotal = numAt(`${g.device}/mem_info_vram_total`)
  const vramUsed = numAt(`${g.device}/mem_info_vram_used`)
  if (Number.isFinite(vramTotal) && vramTotal > 0) {
    dgpuMemText.set(pair(vramUsed, vramTotal))
    dgpuMemFrac.set(clamp(vramUsed / vramTotal))
  }

  const hw = deviceHwmon(g.device)
  if (hw) {
    const milliC = numAt(`${hw}/temp1_input`)
    if (Number.isFinite(milliC)) {
      const t = Math.round(milliC / 1000)
      dgpuTemp.set(t)
      dgpuTempFrac.set(clamp((t - 30) / 70))
    }
  }
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

  const { igpu, dgpu } = detectGpus()
  sampleIgpu(igpu)
  sampleDgpu(dgpu)
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
