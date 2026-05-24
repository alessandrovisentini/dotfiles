import { Variable, bind } from "astal"
import AstalBluetooth from "gi://AstalBluetooth"
import { BLUETOOTH_ICONS } from "../enums/icons"
import { MENU } from "../enums/menu"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"

export function Bluetooth() {
  const bt = AstalBluetooth.get_default()
  const icon = Variable.derive(
    [bind(bt, "isConnected"), bind(bt, "isPowered")],
    (connected: boolean, powered: boolean) =>
      connected
        ? BLUETOOTH_ICONS.connected
        : powered
          ? BLUETOOTH_ICONS.powered
          : BLUETOOTH_ICONS.off,
  )
  return (
    <button
      className="bar-button"
      onClicked={tap(() => toggleMenu(MENU.bluetooth))}
      tooltipText="Bluetooth"
    >
      <label className="bar-icon" label={bind(icon)} />
    </button>
  )
}
