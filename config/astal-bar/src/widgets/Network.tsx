import { Variable, bind } from "astal"
import AstalNetwork from "gi://AstalNetwork"
import { Icon, WIFI_DISABLED } from "../enums/icons"
import { MENU } from "../enums/menu"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"
import { wifiIcon } from "../utils/icons"

export function Network() {
  const net = AstalNetwork.get_default()
  const deps: any[] = [bind(net, "primary"), bind(net, "connectivity")]
  if (net.wifi) {
    deps.push(
      bind(net.wifi, "enabled"),
      bind(net.wifi, "strength"),
      bind(net.wifi, "ssid"),
    )
  }
  const label = Variable.derive(deps, () => {
    const w = net.wifi
    if (net.primary === AstalNetwork.Primary.WIRED) return `${Icon.wired} Wired`
    if (w && w.enabled) return `${wifiIcon(w.strength)} ${w.ssid ?? "Wi-Fi"}`
    return `${WIFI_DISABLED} Off`
  })
  return (
    <button
      className="bar-button"
      onClicked={tap(() => toggleMenu(MENU.network))}
      tooltipText="Network"
    >
      <label label={bind(label)} />
    </button>
  )
}
