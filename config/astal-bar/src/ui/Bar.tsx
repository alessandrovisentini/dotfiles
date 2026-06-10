import { Gtk } from "astal/gtk3"
import type { Reactive } from "../utils/reactive"
import { toBinding } from "../utils/reactive"

type RGB = [number, number, number]

// Fill color by level: green < 30%, yellow 30–70%, red ≥ 70%.
function levelColor(v: number): RGB {
  if (v >= 0.7) return [0.91, 0.26, 0.29]
  if (v >= 0.3) return [0.98, 0.82, 0.25]
  return [0.13, 0.77, 0.37]
}

function roundRect(cr: any, x: number, y: number, w: number, h: number) {
  const r = Math.min(h / 2, w / 2)
  cr.newSubPath()
  cr.arc(x + w - r, y + r, r, -Math.PI / 2, 0)
  cr.arc(x + w - r, y + h - r, r, 0, Math.PI / 2)
  cr.arc(x + r, y + h - r, r, Math.PI / 2, Math.PI)
  cr.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI)
  cr.closePath()
}

// A rounded fill bar for a single 0..1 value, drawn with Cairo. The fill color
// tracks the value (green/yellow/red).
export function Bar(props: { value: Reactive<number>; height?: number }) {
  const { height = 9 } = props
  const value = toBinding(props.value)
  const area = new Gtk.DrawingArea()
  area.hexpand = true
  area.visible = true
  area.set_size_request(-1, height)

  area.connect("draw", (_w: any, cr: any) => {
    const w = area.get_allocated_width()
    const h = area.get_allocated_height()
    const v = Math.max(0, Math.min(1, value.get()))
    const [r, g, b] = levelColor(v)

    // Neutral track.
    roundRect(cr, 0, 0, w, h)
    cr.setSourceRGBA(1, 1, 1, 0.08)
    cr.fill()

    // Fill (at least a dot once non-zero).
    const fw = v <= 0 ? 0 : Math.max(v * w, h)
    if (fw > 0) {
      roundRect(cr, 0, 0, fw, h)
      cr.setSourceRGBA(r, g, b, 1)
      cr.fill()
    }
    return false
  })

  const unsub = value.subscribe(() => area.queue_draw())
  area.connect("destroy", () => unsub())
  return area
}
