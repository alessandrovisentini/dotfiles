// Optimistic boolean intent shared by the bluetooth-power and wifi-enable
// toggles. `value` is null while following the actual state; set() pins the
// user's intent (shown immediately) and reverts after revertMs if the real
// state never catches up; reconcile() clears the intent once it matches.
import { Variable } from "astal"
import GLib from "gi://GLib"

export interface Intent {
  value: Variable<boolean | null>
  set(want: boolean, revertMs?: number): void
  clear(): void
  reconcile(actual: boolean): void
}

export function createIntent(): Intent {
  const value = Variable<boolean | null>(null)
  let timeoutId: number | null = null

  const clear = () => {
    if (timeoutId !== null) {
      GLib.source_remove(timeoutId)
      timeoutId = null
    }
    if (value.get() !== null) value.set(null)
  }

  const set = (want: boolean, revertMs = 5000) => {
    value.set(want)
    if (timeoutId !== null) GLib.source_remove(timeoutId)
    timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, revertMs, () => {
      value.set(null)
      timeoutId = null
      return GLib.SOURCE_REMOVE
    })
  }

  const reconcile = (actual: boolean) => {
    const want = value.get()
    if (want !== null && actual === want) clear()
  }

  return { value, set, clear, reconcile }
}
