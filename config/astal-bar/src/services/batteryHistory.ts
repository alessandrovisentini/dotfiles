// UPower's charge log, used by the battery menu graph. upowerd appends
// "timestamp\tpercent\tstate" to /var/lib/upower/history-charge-<serial>.dat
// whenever the charge or state changes, so reading it back gives days of
// history without logging of our own. Parsed on menu open plus a slow tick
// while it stays open — nothing polls in the background.
import { Variable } from "astal"
import AstalBattery from "gi://AstalBattery"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import { readFile } from "../utils/sysfs"

export type ChargeSample = {
  t: number // unix seconds
  pct: number // 0..100
  onPower: boolean // AC connected (charging / fully-charged / pending-charge)
}

export const chargeHistory = Variable<ChargeSample[]>([])

const DIR = "/var/lib/upower"
const ON_POWER = new Set(["charging", "fully-charged", "pending-charge"])

export function onPowerState(s: AstalBattery.State): boolean {
  const S = AstalBattery.State
  return s === S.CHARGING || s === S.FULLY_CHARGED || s === S.PENDING_CHARGE
}

// The real battery's file carries its serial in the name; "generic_id" is a
// stub upowerd writes for the composite display device. Newest mtime wins if
// several candidates exist.
let file: string | null = null
function findHistoryFile(): string | null {
  try {
    const e = Gio.File.new_for_path(DIR).enumerate_children(
      "standard::name,time::modified",
      Gio.FileQueryInfoFlags.NONE,
      null,
    )
    let best: string | null = null
    let bestM = -1
    let info: Gio.FileInfo | null
    while ((info = e.next_file(null))) {
      const n = info.get_name()
      if (!n.startsWith("history-charge-") || !n.endsWith(".dat")) continue
      if (n.includes("generic_id")) continue
      const m = info.get_attribute_uint64("time::modified")
      if (m > bestM) {
        bestM = m
        best = `${DIR}/${n}`
      }
    }
    return best
  } catch {
    return null
  }
}

function parse(txt: string): ChargeSample[] {
  const out: ChargeSample[] = []
  for (const line of txt.split("\n")) {
    const [ts, value, state] = line.split("\t")
    if (!state || state === "unknown") continue
    // upowerd formats the percent under its own locale — decimal commas here.
    const t = Number(ts)
    const pct = Number(value.replace(",", "."))
    if (!Number.isFinite(t) || !Number.isFinite(pct) || pct <= 0) continue
    out.push({ t, pct, onPower: ON_POWER.has(state) })
  }
  return out
}

export function refreshChargeHistory() {
  if (!file) file = findHistoryFile()
  const txt = file ? readFile(file) : null
  if (txt) chargeHistory.set(parse(txt))
}

let timer = 0
export function startChargeHistory() {
  if (timer) return
  refreshChargeHistory()
  timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60_000, () => {
    refreshChargeHistory()
    return GLib.SOURCE_CONTINUE
  })
}

export function stopChargeHistory() {
  if (timer) {
    GLib.source_remove(timer)
    timer = 0
  }
}
