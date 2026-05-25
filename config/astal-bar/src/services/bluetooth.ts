// Optimistic power-state wrapper around AstalBluetooth. The bar icon
// changes immediately when the user toggles the switch, while bluez +
// rfkill catch up. If they don't, the icon reverts after a timeout.
import { Variable, bind } from "astal"
import AstalBluetooth from "gi://AstalBluetooth"
import GLib from "gi://GLib"

const bt = AstalBluetooth.get_default()

// `null` means "follow bt.isPowered"; otherwise this is the user's intended
// state, shown immediately while bluez transitions.
const intent = Variable<boolean | null>(null)
let timeoutId: number | null = null

function clearIntent() {
  if (timeoutId !== null) {
    GLib.source_remove(timeoutId)
    timeoutId = null
  }
  if (intent.get() !== null) intent.set(null)
}

// Reconcile once bluez agrees with the intent (success path).
bt.connect("notify::is-powered", () => {
  const want = intent.get()
  if (want !== null && bt.isPowered === want) clearIntent()
})

// Public: bar widget reads this; it's optimistic-or-actual.
export const poweredView = Variable.derive(
  [intent, bind(bt, "isPowered")],
  (want, actual) => (want !== null ? want : actual),
)

// Public: menu calls this on user toggle. Reverts after `revertMs` if the
// actual state never catches up (e.g. rfkill kept it blocked).
export function setPoweredIntent(want: boolean, revertMs = 5000) {
  intent.set(want)
  if (timeoutId !== null) GLib.source_remove(timeoutId)
  timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, revertMs, () => {
    intent.set(null)
    timeoutId = null
    return GLib.SOURCE_REMOVE
  })
}
