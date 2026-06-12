import { Variable, bind } from "astal"
import AstalNetwork from "gi://AstalNetwork"
import { Icon, WIFI_DISABLED, WIFI_RAMP } from "../const/icons"
import { MENU } from "../const/menu"
import { toggleMenu } from "../services/menu"
import { type WifiState, wifiState } from "../services/wifi"
import { tap } from "../utils/gtk"
import { wifiIcon } from "../utils/icons"
import { own } from "../utils/reactive"

export function Network() {
  const net = AstalNetwork.get_default()
  // wifi state via wifiState (re-subscribes across device swaps); primary/
  // connectivity are safe to bind directly off the stable singleton.
  const deps = [bind(net, "primary"), bind(net, "connectivity"), wifiState]
  // ssid lingers after disconnect, so gate it on internet === CONNECTED.
  const isWifiConnected = (st: WifiState) =>
    !!st.device && st.internet === AstalNetwork.Internet.CONNECTED
  const label = Variable.derive(deps, (primary, _conn, st) => {
    if (primary === AstalNetwork.Primary.WIRED) return `${Icon.wired} Wired`
    if (st.device && st.enabled) {
      if (isWifiConnected(st) && st.ssid) return `${wifiIcon(st.strength)} ${st.ssid}`
      return `${WIFI_RAMP.off} Wi-Fi`
    }
    return `${WIFI_DISABLED} Off`
  })
  const cls = Variable.derive(deps, (primary, _conn, st) => {
    if (primary === AstalNetwork.Primary.WIRED) return "bar-button state-wifi-on"
    if (st.device && st.enabled)
      return `bar-button ${isWifiConnected(st) ? "state-wifi-on" : "state-net-on"}`
    return "bar-button"
  })
  return (
    <button
      className={bind(cls)}
      onClicked={tap((self) => toggleMenu(MENU.network, self))}
      tooltipText="Network"
      setup={own(label, cls)}
    >
      <label label={bind(label)} />
    </button>
  )
}
