// Optimistic power-state wrapper around AstalBluetooth. The bar icon
// changes immediately when the user toggles the switch, while bluez +
// rfkill catch up. If they don't, the icon reverts after a timeout.
import { Variable, bind } from "astal"
import AstalBluetooth from "gi://AstalBluetooth"
import { createIntent } from "./intent"

const bt = AstalBluetooth.get_default()
const intent = createIntent()

// Reconcile once bluez agrees with the intent (success path).
bt.connect("notify::is-powered", () => intent.reconcile(bt.isPowered))

// Optimistic-or-actual power state read by the bar widget.
export const poweredView = Variable.derive(
  [intent.value, bind(bt, "isPowered")],
  (want, actual) => (want !== null ? want : actual),
)

// Called by the menu on user toggle; reverts after revertMs if the actual
// state never catches up (e.g. rfkill kept it blocked).
export const setPoweredIntent = intent.set
