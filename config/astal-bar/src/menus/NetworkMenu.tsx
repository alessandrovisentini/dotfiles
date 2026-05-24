import { bind } from "astal"
import { execAsync } from "astal/process"
import { Gtk } from "astal/gtk3"
import AstalNetwork from "gi://AstalNetwork"
import { Icon } from "../enums/icons"
import { MENU } from "../enums/menu"
import { HeaderButton } from "../ui/HeaderButton"
import { Row } from "../ui/Row"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
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
  const forget = (ssid: string) => sh(["nmcli", "connection", "delete", "id", ssid])

  const apRows = () => {
    const w = net.wifi
    if (!w)
      return (
        <label className="subtle" label="No Wi-Fi device" halign={Gtk.Align.START} />
      )
    const seen = new Set<string>()
    const rows = w.accessPoints
      .filter((ap) => ap.ssid)
      .sort((a, b) => b.strength - a.strength)
      .filter((ap) => !seen.has(ap.ssid!) && seen.add(ap.ssid!))
      .slice(0, 20)
      .map((ap) => {
        const active = ap.ssid === w.ssid
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
          action: active
            ? HeaderButton(Icon.remove, () => forget(ap.ssid!), "Forget")
            : undefined,
        })
      })
    return rows.length ? (
      rows
    ) : (
      <label className="subtle" label="No networks found" halign={Gtk.Align.START} />
    )
  }

  const ethernet = Row({
    active: net.primary === AstalNetwork.Primary.WIRED,
    icon: Icon.wired,
    name: "Wired",
    status:
      net.primary === AstalNetwork.Primary.WIRED ? "Connected" : "Unplugged",
  })

  const wifiHeader = (
    <box>
      <switch
        valign={Gtk.Align.CENTER}
        active={net.wifi ? bind(net.wifi, "enabled") : false}
        onStateSet={(_, state) => {
          if (net.wifi) net.wifi.enabled = state
        }}
      />
      {HeaderButton(Icon.scan, () => net.wifi?.scan(), "Scan")}
      {HeaderButton(Icon.settings, () => sh(["nm-connection-editor"]), "Settings")}
    </box>
  )

  return MenuWindow({
    name: MENU.network,
    klass: "net",
    child: (
      <box vertical>
        {Section("Ethernet", ethernet)}
        {Section(
          "Wi-Fi",
          ScrollList(
            net.wifi ? bind(net.wifi, "accessPoints").as(() => apRows()) : apRows(),
          ),
          wifiHeader,
        )}
      </box>
    ),
  })
}
