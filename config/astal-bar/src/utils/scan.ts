import { Binding, Variable, bind } from "astal"
import GLib from "gi://GLib"
import { SCAN_GRACE_MS } from "../const/ui"

// Scan-feedback helper. `busy` reads true while `active` is true OR within
// graceMs of the last ping(). Call ping() on the scan button so the spinner
// always shows even if the backend throttles or flips `active` back too fast.
// A new ping cancels the previous timer so repeated clicks don't stack.
export function useScanPing(
  active: Binding<boolean>,
  graceMs = SCAN_GRACE_MS,
): { busy: Binding<boolean>; ping: () => void } {
  const pinged = Variable(false)
  let timer: number | null = null
  const busy = Variable.derive([pinged, active], (p, a) => p || a)
  const ping = () => {
    pinged.set(true)
    if (timer !== null) GLib.source_remove(timer)
    timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, graceMs, () => {
      pinged.set(false)
      timer = null
      return GLib.SOURCE_REMOVE
    })
  }
  return { busy: bind(busy), ping }
}
