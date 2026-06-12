import { Variable, bind } from "astal"
import { Gtk } from "astal/gtk3"
import GLib from "gi://GLib"
import AstalBluetooth from "gi://AstalBluetooth"
import { BLUETOOTH_ICONS, Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { BT_DISCOVERY_MS } from "../const/ui"
import { namedDevices, poweredView, setPoweredIntent } from "../services/bluetooth"
import { EmptyState } from "../ui/EmptyState"
import { HeaderButton } from "../ui/HeaderButton"
import { Row } from "../ui/Row"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { sh } from "../utils/shell"
import { useScanPing } from "../utils/scan"
import { MenuWindow } from "./MenuWindow"

export function BluetoothMenu() {
  const bt = AstalBluetooth.get_default()
  // Track per-device "action in flight" state so each row can show a spinner.
  // Entries are pruned when bluez forgets the device.
  const busyMap = new Map<
    string,
    { v: Variable<boolean>; dev: AstalBluetooth.Device; id: number }
  >()
  const busyFor = (dev: AstalBluetooth.Device) => {
    let e = busyMap.get(dev.address)
    if (!e) {
      const v = Variable(false)
      // External connect/disconnect should also clear the spinner.
      e = { v, dev, id: dev.connect("notify::connected", () => v.set(false)) }
      busyMap.set(dev.address, e)
    }
    return e.v
  }
  const pruneBusy = (devs: AstalBluetooth.Device[]) => {
    const alive = new Set(devs.map((d) => d.address))
    for (const [addr, e] of busyMap) {
      if (alive.has(addr)) continue
      try { e.dev.disconnect(e.id) } catch {}
      busyMap.delete(addr)
    }
  }

  // dev.connect_device() silently no-ops in GJS without a callback.
  const connect = async (dev: AstalBluetooth.Device) => {
    const busy = busyFor(dev)
    if (busy.get()) return
    busy.set(true)
    try {
      await sh([
        "bluetoothctl",
        dev.connected ? "disconnect" : "connect",
        dev.address,
      ])
    } finally {
      busy.set(false)
    }
  }

  const row = (dev: AstalBluetooth.Device) => {
    const busy = bind(busyFor(dev))
    const connected = bind(dev, "connected")
    const status = Variable.derive(
      [connected, busy, bind(dev, "batteryPercentage")],
      (c: boolean, b: boolean, bat: number) => {
        if (b) return c ? "Disconnecting…" : "Connecting…"
        if (c) return bat > 0 ? `Connected · ${Math.round(bat * 100)}%` : "Connected"
        return dev.paired ? "Paired" : "Not paired"
      },
    )
    return Row({
      icon: connected.as((c) =>
        c ? BLUETOOTH_ICONS.connected : BLUETOOTH_ICONS.powered,
      ),
      name: dev.name ?? dev.address,
      active: connected,
      busy,
      status: bind(status),
      owns: [status],
      onClicked: () => connect(dev),
    })
  }

  // Scan feedback: spin while bluez is discovering OR for the grace window
  // after a click.
  const scan = useScanPing(
    bt.adapter ? bind(bt.adapter, "discovering") : bind(Variable(false)),
  )

  // BlueZ discovery never stops on its own, so bound each scan to a window and
  // stop it afterwards — otherwise `discovering` (and the spinner) stay on
  // forever. A new click resets the timer instead of stacking another stop.
  let discoveryTimer: number | null = null
  const startScan = () => {
    const adapter = bt.adapter
    if (!adapter) return
    adapter.start_discovery()
    scan.ping()
    if (discoveryTimer !== null) GLib.source_remove(discoveryTimer)
    discoveryTimer = GLib.timeout_add(
      GLib.PRIORITY_DEFAULT,
      BT_DISCOVERY_MS,
      () => {
        if (bt.adapter?.discovering) bt.adapter.stop_discovery()
        discoveryTimer = null
        return GLib.SOURCE_REMOVE
      },
    )
  }

  const header = (
    <box>
      <switch
        valign={Gtk.Align.CENTER}
        // poweredView (not raw isPowered) so the switch flips optimistically
        // together with the bar icon instead of lagging until bluez settles.
        active={bind(poweredView)}
        onStateSet={(_, state) => {
          setPoweredIntent(state)
          // When the adapter is rfkill-blocked (Fn key, prior block), a bare
          // `bluetoothctl power on` succeeds silently without actually
          // powering the controller. Chain the rfkill flip so the switch
          // really toggles the radio. Off mirrors that: power off + block,
          // matching how the system tray toggle behaves on most laptops.
          const cmd = state
            ? "rfkill unblock bluetooth && bluetoothctl power on"
            : "bluetoothctl power off; rfkill block bluetooth"
          sh(["sh", "-c", cmd])
        }}
      />
      {HeaderButton(Icon.scan, startScan, "Scan", scan.busy)}
      {HeaderButton(Icon.settings, () => sh(["blueman-manager"]), "Settings")}
    </box>
  )

  return MenuWindow({
    name: MENU.bluetooth,
    klass: "bt",
    child: (
      <box vertical>
        {Section(
          "Bluetooth",
          ScrollList(
            Variable.derive(
              [bind(namedDevices), bind(poweredView)],
              (devs: AstalBluetooth.Device[], powered: boolean) => {
                if (!powered) return EmptyState("Bluetooth off")
                pruneBusy(devs)
                return devs.length
                  ? devs.map((d) => row(d))
                  : EmptyState("No devices")
              },
            )(),
          ),
          header,
        )}
      </box>
    ),
  })
}
