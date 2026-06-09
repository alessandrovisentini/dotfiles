import { Variable, bind } from "astal"
import { execAsync } from "astal/process"
import { Gtk } from "astal/gtk3"
import AstalNetwork from "gi://AstalNetwork"
import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { enabledView, setEnabledIntent, wifiState } from "../services/wifi"
import {
  busyFor as vpnBusyFor,
  toggleVpn,
  vpns,
  type VpnEntry,
} from "../services/vpn"
import { EmptyState } from "../ui/EmptyState"
import { HeaderButton } from "../ui/HeaderButton"
import { Row } from "../ui/Row"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { useScanPing } from "../utils/scan"
import { wifiIcon } from "../utils/icons"
import { sh } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

export function NetworkMenu() {
  const net = AstalNetwork.get_default()
  // Fall back to the editor for secured-unknown networks (passphrase prompt).
  const connect = (ssid: string) =>
    execAsync(["nmcli", "device", "wifi", "connect", ssid]).catch(() =>
      sh(["nm-connection-editor"]),
    )

  const scan = useScanPing(bind(wifiState).as((st) => st.scanning))

  const apRows = () => {
    const st = wifiState.get()
    if (!st.device) return EmptyState("No Wi-Fi device")
    const seen = new Set<string>()
    const rows = st.accessPoints
      .filter((ap) => ap.ssid)
      .sort((a, b) => b.strength - a.strength)
      .filter((ap) => !seen.has(ap.ssid!) && seen.add(ap.ssid!))
      .slice(0, 20)
      .map((ap) => {
        const active = ap.ssid === st.ssid
        return Row({
          active,
          icon: wifiIcon(ap.strength),
          name: ap.ssid!,
          status: active
            ? "Connected"
            : ap.requiresPassword
              ? "Secured"
              : "Open",
          onClicked: () => connect(ap.ssid!),
        })
      })
    return rows.length ? rows : EmptyState("No networks found")
  }

  const ethernetRow = () => {
    const wired = net.primary === AstalNetwork.Primary.WIRED
    return Row({
      active: wired,
      icon: Icon.wired,
      name: "Wired",
      status: wired ? "Connected" : "Unplugged",
    })
  }

  const wifiHeader = (
    <box>
      <switch
        valign={Gtk.Align.CENTER}
        active={bind(enabledView)}
        onStateSet={(_, state) => {
          // Optimistic: pin the view to the user's intent so NM's mid-
          // transition `enabled` flickers don't yank the switch back. The
          // intent reconciles once NM settles, or reverts after 5 s if it
          // never does (e.g. rfkill kept the radio blocked).
          setEnabledIntent(state)
          // Toggle via nmcli so the GTK main loop isn't blocked while NM
          // brings the radio up/down.
          sh(["nmcli", "radio", "wifi", state ? "on" : "off"])
        }}
      />
      {HeaderButton(
        Icon.scan,
        () => {
          net.wifi?.scan()
          scan.ping()
        },
        "Scan",
        scan.busy,
      )}
      {HeaderButton(Icon.settings, () => sh(["nm-connection-editor"]), "Settings")}
    </box>
  )

  const vpnRow = (entry: VpnEntry) => {
    const busy = bind(vpnBusyFor(entry.uuid))
    return Row({
      icon: Icon.vpn,
      name: entry.name,
      active: entry.active,
      busy,
      status: busy.as((b) =>
        b
          ? entry.active
            ? "Disconnecting…"
            : "Connecting…"
          : entry.active
            ? "Connected"
            : "Disconnected",
      ),
      onClicked: () => toggleVpn(entry),
    })
  }

  const vpnHeader = (
    <box>
      {HeaderButton(
        Icon.add,
        () => sh(["nm-connection-editor", "--create", "--type=vpn"]),
        "Add VPN",
      )}
      {HeaderButton(Icon.settings, () => sh(["nm-connection-editor"]), "Settings")}
    </box>
  )

  return MenuWindow({
    name: MENU.network,
    klass: "net",
    child: (
      <box vertical>
        {Section("Ethernet", bind(net, "primary").as(() => ethernetRow()))}
        {Section(
          "Wi-Fi",
          ScrollList(Variable.derive([wifiState], () => apRows())()),
          wifiHeader,
        )}
        {Section(
          "VPN",
          ScrollList(
            bind(vpns).as((list) =>
              list.length
                ? list.map((v) => vpnRow(v))
                : EmptyState("No VPN configs"),
            ),
          ),
          vpnHeader,
        )}
      </box>
    ),
  })
}
