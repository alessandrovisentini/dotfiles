import { bind } from "astal"
import { Gtk } from "astal/gtk3"
import AstalBattery from "gi://AstalBattery"
import GLib from "gi://GLib"
import {
  chargeHistory,
  onPowerState,
  refreshChargeHistory,
  type ChargeSample,
} from "../services/batteryHistory"

// iOS-style battery chart: charge level over the last 24 h, with shaded
// bands (plus a plug glyph at their left edge) marking the periods the
// device was connected to power.

type RGB = [number, number, number]

const HOURS = 24
const HEIGHT = 170
const PAD_T = 16 // top margin: plug glyphs live here
const PAD_B = 20 // bottom margin: hour labels
const PAD_L = 6
const PAD_R = 42 // right margin: % labels
// No samples for this long means the machine was off/suspended; the
// connector across it is drawn dashed instead of pretending we measured it.
const GAP = 2 * 3600

// style.scss tokens.
const LEVEL: RGB = [0.086, 0.639, 0.29] // $batt-ok #16a34a
const POWER: RGB = [0.208, 0.518, 0.894] // $accent #3584e4
const MUTED: RGB = [0.604, 0.6, 0.588] // $muted #9a9996

const PLUG = "󰚥"

// Build the polyline for the window: entry point interpolated at the left
// edge from the last sample before it, the in-window samples, and a final
// "now" point from the live battery state.
function points(bat: AstalBattery.Device, start: number, now: number) {
  const hist = chargeHistory.get()
  const before = hist.filter((s) => s.t < start).at(-1)
  const within = hist.filter((s) => s.t >= start && s.t <= now)
  const pts: ChargeSample[] = []
  if (before) {
    const f = within[0]
    const pct = f
      ? before.pct + ((f.pct - before.pct) * (start - before.t)) / (f.t - before.t)
      : before.pct
    pts.push({ t: start, pct, onPower: before.onPower })
  }
  pts.push(...within)
  pts.push({ t: now, pct: bat.percentage * 100, onPower: onPowerState(bat.state) })
  return pts
}

function draw(area: Gtk.DrawingArea, cr: any, bat: AstalBattery.Device) {
  const w = area.get_allocated_width()
  const h = area.get_allocated_height()
  const now = Math.floor(GLib.get_real_time() / 1e6)
  const start = now - HOURS * 3600
  const x0 = PAD_L
  const x1 = w - PAD_R
  const y0 = PAD_T
  const y1 = h - PAD_B
  const X = (t: number) => x0 + ((t - start) / (HOURS * 3600)) * (x1 - x0)
  const Y = (p: number) => y1 - (p / 100) * (y1 - y0)

  cr.selectFontFace("DejaVuSansM Nerd Font Mono", 0, 0)
  cr.setLineWidth(1)

  // Horizontal grid + right-side % labels.
  cr.setFontSize(10)
  for (const p of [0, 50, 100]) {
    cr.setSourceRGBA(1, 1, 1, 0.08)
    cr.moveTo(x0, Y(p))
    cr.lineTo(x1, Y(p))
    cr.stroke()
    cr.setSourceRGBA(...MUTED, 0.9)
    cr.moveTo(x1 + 7, Y(p) + 3.5)
    cr.showText(`${p}%`)
  }

  // Vertical ticks + hour labels on round local 6-hour marks.
  const first = GLib.DateTime.new_from_unix_local(start)
  let tick = GLib.DateTime.new_local(
    first.get_year(),
    first.get_month(),
    first.get_day_of_month(),
    first.get_hour() - (first.get_hour() % 6),
    0,
    0,
  )
  while (tick.to_unix() < start) tick = tick.add_hours(6)
  for (; tick.to_unix() <= now; tick = tick.add_hours(6)) {
    const x = X(tick.to_unix())
    cr.setSourceRGBA(1, 1, 1, 0.05)
    cr.moveTo(x, y0)
    cr.lineTo(x, y1)
    cr.stroke()
    const lbl = tick.format("%H") ?? ""
    const ext = cr.textExtents(lbl)
    cr.setSourceRGBA(...MUTED, 0.9)
    cr.moveTo(x - ext.width / 2, h - 6)
    cr.showText(lbl)
  }

  const pts = points(bat, start, now)
  if (pts.length < 2) {
    cr.setSourceRGBA(...MUTED, 0.9)
    const msg = "No history yet"
    const ext = cr.textExtents(msg)
    cr.moveTo((w - ext.width) / 2, (y0 + y1) / 2)
    cr.showText(msg)
    return
  }

  // Area fill under the whole curve.
  cr.moveTo(X(pts[0].t), Y(pts[0].pct))
  for (const p of pts.slice(1)) cr.lineTo(X(p.t), Y(p.pct))
  cr.lineTo(X(pts[pts.length - 1].t), y1)
  cr.lineTo(X(pts[0].t), y1)
  cr.closePath()
  cr.setSourceRGBA(...LEVEL, 0.13)
  cr.fill()

  // On-power bands, over the area fill so they read blue rather than
  // blending into it. Sample i's state holds until sample i+1.
  const bands: Array<[number, number]> = []
  for (let i = 0; i < pts.length - 1; i++) {
    if (!pts[i].onPower) continue
    const last = bands[bands.length - 1]
    if (last && pts[i].t <= last[1] + 60) last[1] = pts[i + 1].t
    else bands.push([pts[i].t, pts[i + 1].t])
  }
  for (const [a, b] of bands) {
    cr.setSourceRGBA(...POWER, 0.12)
    cr.rectangle(X(a), y0, X(b) - X(a), y1 - y0)
    cr.fill()
    // Plug-in moment: dashed edge + plug glyph in the top margin.
    cr.setDash([3, 3], 0)
    cr.setSourceRGBA(...POWER, 0.7)
    cr.moveTo(X(a), y0)
    cr.lineTo(X(a), y1)
    cr.stroke()
    cr.setDash([], 0)
    if (X(b) - X(a) > 16) {
      cr.setFontSize(12)
      cr.setSourceRGBA(...POWER, 1)
      cr.moveTo(X(a) + 4, y0 - 4)
      cr.showText(PLUG)
    }
  }

  // The level line, segment by segment so data gaps render dashed.
  cr.setLineWidth(2)
  cr.setLineCap(1) // cairo ROUND
  cr.setLineJoin(1)
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i]
    const b = pts[i + 1]
    const gap = b.t - a.t > GAP
    cr.setDash(gap ? [3, 5] : [], 0)
    cr.setSourceRGBA(...LEVEL, gap ? 0.45 : 1)
    cr.moveTo(X(a.t), Y(a.pct))
    cr.lineTo(X(b.t), Y(b.pct))
    cr.stroke()
  }
  cr.setDash([], 0)

  // Dot on "now".
  const last = pts[pts.length - 1]
  cr.setSourceRGBA(...LEVEL, 1)
  cr.arc(X(last.t), Y(last.pct), 3, 0, 2 * Math.PI)
  cr.fill()
}

export function ChargeGraph() {
  const bat = AstalBattery.get_default()
  const area = new Gtk.DrawingArea()
  area.hexpand = true
  area.visible = true
  area.set_size_request(-1, HEIGHT)
  area.connect("draw", (_w: any, cr: any) => {
    draw(area, cr, bat)
    return false
  })
  const unsubs = [
    chargeHistory.subscribe(() => area.queue_draw()),
    bind(bat, "percentage").subscribe(() => area.queue_draw()),
    // Plug/unplug: upowerd logs the state change immediately; re-read so the
    // new band starts without waiting for the next slow tick.
    bind(bat, "state").subscribe(() => refreshChargeHistory()),
  ]
  area.connect("destroy", () => unsubs.forEach((u) => u()))
  return area
}
