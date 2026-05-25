import { Variable, bind } from "astal"
import AstalBluetooth from "gi://AstalBluetooth"
import { BLUETOOTH_ICONS } from "../const/icons"
import { MENU } from "../const/menu"
import { poweredView } from "../services/bluetooth"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Bluetooth() {
  const bt = AstalBluetooth.get_default()
  const deps = [bind(bt, "isConnected"), bind(poweredView)]
  const icon = Variable.derive(
    deps,
    (connected: boolean, powered: boolean) =>
      connected && powered
        ? BLUETOOTH_ICONS.connected
        : powered
          ? BLUETOOTH_ICONS.powered
          : BLUETOOTH_ICONS.off,
  )
  const cls = Variable.derive(
    deps,
    (connected: boolean, powered: boolean) =>
      connected && powered
        ? "bar-button state-bt-on"
        : powered
          ? "bar-button state-bt-rdy"
          : "bar-button",
  )
  return (
    <button
      className={bind(cls)}
      onClicked={tap(() => toggleMenu(MENU.bluetooth))}
      tooltipText="Bluetooth"
    >
      <label className="bar-icon" label={bind(icon)} />
    </button>
  )
}
