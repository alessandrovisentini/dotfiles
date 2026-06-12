import { Gtk } from "astal/gtk3"
import GLib from "gi://GLib"

// GTK3 leaves :hover stuck on tap; clear it on the next idle tick.
export function unstick(w: any) {
  GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
    w?.unset_state_flags(Gtk.StateFlags.PRELIGHT | Gtk.StateFlags.ACTIVE)
    return GLib.SOURCE_REMOVE
  })
}

export const tap = (fn: (self: any) => void) => (self: any) => {
  fn(self)
  unstick(self)
}
