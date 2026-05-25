import { Variable, bind } from "astal"
import { Gtk } from "astal/gtk3"
import AstalBluetooth from "gi://AstalBluetooth"
import GLib from "gi://GLib"
import { BLUETOOTH_ICONS, Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { poweredView, setPoweredIntent } from "../services/bluetooth"
import { HeaderButton } from "../ui/HeaderButton"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { Spinner } from "../ui/Spinner"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

export function BluetoothMenu() {
  const bt = AstalBluetooth.get_default()
  // Track per-device "action in flight" state so each row can show a spinner.
  const busyMap = new Map<string, Variable<boolean>>()
  const busyFor = (dev: AstalBluetooth.Device) => {
    let v = busyMap.get(dev.address)
    if (!v) {
      v = Variable(false)
      busyMap.set(dev.address, v)
      // External connect/disconnect should also clear the spinner. Registered
      // once per device on first access so devices.changed re-renders don't
      // leak listeners.
      dev.connect("notify::connected", () => v!.set(false))
    }
    return v
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

  // Inline so each row re-renders on its own `connected` change.
  const row = (dev: AstalBluetooth.Device) => {
    const busy = busyFor(dev)
    const iconLabel = bind(dev, "connected").as((c) =>
      c ? BLUETOOTH_ICONS.connected : BLUETOOTH_ICONS.powered,
    )
    return (
      <button
        className={bind(dev, "connected").as((c) => `dev-row ${c ? "active" : ""}`)}
        onClicked={tap(() => connect(dev))}
      >
        <box>
          {bind(busy).as((b) =>
            b ? (
              <box className="dev-icon" valign={Gtk.Align.CENTER}>
                <Spinner active={busy} size={22} />
              </box>
            ) : (
              <label
                className="dev-icon"
                valign={Gtk.Align.CENTER}
                label={iconLabel}
              />
            ),
          )}
          <box vertical halign={Gtk.Align.START} hexpand valign={Gtk.Align.CENTER}>
            <label
              className="dev-name"
              label={dev.name ?? dev.address}
              halign={Gtk.Align.START}
              truncate
            />
            <label
              className="subtle"
              halign={Gtk.Align.START}
              label={Variable.derive(
                [bind(dev, "connected"), bind(busy)],
                (c: boolean, b: boolean) => {
                  if (b) return c ? "Disconnecting…" : "Connecting…"
                  if (c) {
                    const bat = dev.batteryPercentage
                    return bat > 0
                      ? `Connected · ${Math.round(bat * 100)}%`
                      : "Connected"
                  }
                  return dev.paired ? "Paired" : "Not paired"
                },
              )()}
            />
          </box>
        </box>
      </button>
    )
  }

  // Scan feedback: spin while bluez is discovering OR for ~1.2 s after click.
  const scanPing = Variable(false)
  const scanBusy = bt.adapter
    ? Variable.derive(
        [scanPing, bind(bt.adapter, "discovering")],
        (p, d) => p || d,
      )
    : scanPing

  const header = (
    <box>
      <switch
        valign={Gtk.Align.CENTER}
        active={bind(bt, "isPowered")}
        onStateSet={(_, state) => {
          // Optimistic: flip the bar icon immediately; the service reverts
          // it if the actual state never catches up.
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
      {HeaderButton(
        Icon.scan,
        () => {
          bt.adapter?.start_discovery()
          scanPing.set(true)
          GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1200, () => {
            scanPing.set(false)
            return GLib.SOURCE_REMOVE
          })
        },
        "Scan",
        scanBusy,
      )}
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
              [bind(bt, "devices"), bind(poweredView)],
              (devs: AstalBluetooth.Device[], powered: boolean) => {
                const empty = (text: string) => (
                  <box
                    className="notif-empty"
                    hexpand
                    vexpand
                    halign={Gtk.Align.CENTER}
                    valign={Gtk.Align.CENTER}
                  >
                    <label className="subtle" label={text} />
                  </box>
                )
                if (!powered) return empty("Bluetooth off")
                const named = devs.filter((d) => d.name)
                return named.length
                  ? named.map((d) => row(d))
                  : empty("No devices")
              },
            )(),
          ),
          header,
        )}
      </box>
    ),
  })
}
