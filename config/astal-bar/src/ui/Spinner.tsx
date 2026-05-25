// Cairo-drawn 8-dot square spinner. Renders directly on a Gtk.DrawingArea
// (no wrapping box) so size requests propagate correctly. The active dot
// rotates with a brightness-trail fade to make the direction obvious.
import GLib from "gi://GLib"

const N_DOTS = 8

export function Spinner({ active, size = 20 }: { active?: any; size?: number }) {
  let phase = 0
  let tickId: number | null = null

  return (
    <drawingarea
      className="cs-spinner"
      setup={(self: any) => {
        self.set_size_request(size, size)
        self.set_has_window?.(false)

        self.connect("draw", (_w: any, cr: any) => {
          const w = self.get_allocated_width()
          const h = self.get_allocated_height()
          const cx = w / 2
          const cy = h / 2
          const r = Math.min(w, h) / 2 - 1
          const dotR = Math.max(1.2, r * 0.22)
          for (let k = 0; k < N_DOTS; k++) {
            const angle = (k / N_DOTS) * 2 * Math.PI - Math.PI / 2
            const px = cx + (r - dotR) * Math.cos(angle)
            const py = cy + (r - dotR) * Math.sin(angle)
            const dist = (phase - k + N_DOTS) % N_DOTS
            const alpha = Math.max(0.15, 1 - dist * 0.13)
            cr.setSourceRGBA(1, 1, 1, alpha)
            cr.arc(px, py, dotR, 0, 2 * Math.PI)
            cr.fill()
          }
          return false
        })

        const start = () => {
          if (tickId !== null) return
          tickId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            phase = (phase + 1) % N_DOTS
            self.queue_draw()
            return GLib.SOURCE_CONTINUE
          })
        }
        const stop = () => {
          if (tickId !== null) {
            GLib.source_remove(tickId)
            tickId = null
          }
        }

        if (active && typeof active.subscribe === "function") {
          const apply = (v: boolean) => (v ? start() : stop())
          try { apply(active.get()) } catch { start() }
          const sub = active.subscribe(apply)
          self.connect("destroy", () => { stop(); sub?.() })
        } else {
          start()
          self.connect("destroy", () => stop())
        }
      }}
    />
  )
}
