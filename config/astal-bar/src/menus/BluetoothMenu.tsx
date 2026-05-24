import { bind } from "astal"
import { Gtk } from "astal/gtk3"
import AstalBluetooth from "gi://AstalBluetooth"
import { BLUETOOTH_ICONS, Icon } from "../enums/icons"
import { MENU } from "../enums/menu"
import { HeaderButton } from "../ui/HeaderButton"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { tap } from "../utils/gtk"
import { sh } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

export function BluetoothMenu() {
  const bt = AstalBluetooth.get_default()
  // dev.connect_device() silently no-ops in GJS without a callback.
  const connect = (dev: AstalBluetooth.Device) =>
    sh(["bluetoothctl", dev.connected ? "disconnect" : "connect", dev.address])
  const remove = (addr: string) => sh(["bluetoothctl", "remove", addr])

  // Inline so each row re-renders on its own `connected` change.
  const row = (dev: AstalBluetooth.Device) => (
    <button
      className={bind(dev, "connected").as((c) => `dev-row ${c ? "active" : ""}`)}
      onClicked={tap(() => connect(dev))}
    >
      <box>
        <label
          className="dev-icon"
          valign={Gtk.Align.CENTER}
          label={bind(dev, "connected").as((c) =>
            c ? BLUETOOTH_ICONS.connected : BLUETOOTH_ICONS.powered,
          )}
        />
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
            label={bind(dev, "connected").as((c) => {
              if (c) {
                const b = dev.batteryPercentage
                return b > 0 ? `Connected · ${Math.round(b * 100)}%` : "Connected"
              }
              return dev.paired ? "Paired" : "Not paired"
            })}
          />
        </box>
        {HeaderButton(Icon.remove, () => remove(dev.address), "Remove")}
      </box>
    </button>
  )

  const header = (
    <box>
      <switch
        valign={Gtk.Align.CENTER}
        active={bind(bt, "isPowered")}
        onStateSet={(_, state) => {
          if (bt.adapter) bt.adapter.powered = state
        }}
      />
      {HeaderButton(Icon.scan, () => bt.adapter?.start_discovery(), "Scan")}
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
            bind(bt, "devices").as((devs) =>
              devs.filter((d) => d.name).length ? (
                devs.filter((d) => d.name).map((d) => row(d))
              ) : (
                <label className="subtle" label="No devices" halign={Gtk.Align.START} />
              ),
            ),
          ),
          header,
        )}
      </box>
    ),
  })
}
