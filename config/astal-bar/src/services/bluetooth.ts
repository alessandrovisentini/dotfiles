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

// Named devices, sorted connected > paired > name. `devices` only notifies
// on add/remove, but bluez often adds a discovered device first and resolves
// its name afterwards — without re-publishing on notify::name those devices
// would never appear in the menu. notify::connected/paired re-publish too so
// the sort order stays truthful.
export const namedDevices = Variable<AstalBluetooth.Device[]>([])

function publishDevices() {
  const named = bt.get_devices().filter((d) => d.name)
  named.sort(
    (a, b) =>
      Number(b.connected) - Number(a.connected) ||
      Number(b.paired) - Number(a.paired) ||
      a.name.localeCompare(b.name),
  )
  namedDevices.set(named)
}

const watched = new Map<AstalBluetooth.Device, number[]>()

function watchDevice(dev: AstalBluetooth.Device) {
  if (watched.has(dev)) return
  watched.set(dev, [
    dev.connect("notify::name", publishDevices),
    dev.connect("notify::connected", publishDevices),
    dev.connect("notify::paired", publishDevices),
  ])
}

bt.get_devices().forEach(watchDevice)
bt.connect("device-added", (_b, dev: AstalBluetooth.Device) => {
  watchDevice(dev)
  publishDevices()
})
bt.connect("device-removed", (_b, dev: AstalBluetooth.Device) => {
  for (const id of watched.get(dev) ?? []) {
    try { dev.disconnect(id) } catch {}
  }
  watched.delete(dev)
  publishDevices()
})
publishDevices()
