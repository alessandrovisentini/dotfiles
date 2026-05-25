// Optimistic wifi-enabled wrapper around AstalNetwork. NM cycles the
// `enabled` property through false/true several times while bringing the
// radio up; without an intent layer those transitions race the user's
// click and the switch flickers (and sometimes gets stuck off). The
// menu writes an intent here, the menu's switch reads it, and the
// intent self-clears when NM agrees — or reverts after 5 s if it doesn't.
import { Variable, bind } from "astal"
import AstalNetwork from "gi://AstalNetwork"
import GLib from "gi://GLib"

const net = AstalNetwork.get_default()

const intent = Variable<boolean | null>(null)
let timeoutId: number | null = null

function clearIntent() {
  if (timeoutId !== null) {
    GLib.source_remove(timeoutId)
    timeoutId = null
  }
  if (intent.get() !== null) intent.set(null)
}

if (net.wifi) {
  net.wifi.connect("notify::enabled", () => {
    const want = intent.get()
    if (want !== null && net.wifi!.enabled === want) clearIntent()
  })
}

export const enabledView: Variable<boolean> = net.wifi
  ? Variable.derive(
      [intent, bind(net.wifi, "enabled")],
      (want, actual) => (want !== null ? want : actual),
    )
  : Variable(false)

export function setEnabledIntent(want: boolean, revertMs = 5000) {
  intent.set(want)
  if (timeoutId !== null) GLib.source_remove(timeoutId)
  timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, revertMs, () => {
    intent.set(null)
    timeoutId = null
    return GLib.SOURCE_REMOVE
  })
}
