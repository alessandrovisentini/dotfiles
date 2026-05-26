import { Variable, bind } from "astal"
import { execAsync } from "astal/process"
import { Gtk } from "astal/gtk3"
import AstalNetwork from "gi://AstalNetwork"
import GLib from "gi://GLib"
import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { enabledView, setEnabledIntent } from "../services/wifi"
import {
  busyFor as vpnBusyFor,
  toggleVpn,
  vpns,
  type VpnEntry,
} from "../services/vpn"
import { HeaderButton } from "../ui/HeaderButton"
import { Row } from "../ui/Row"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { Spinner } from "../ui/Spinner"
import { tap } from "../utils/gtk"
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

  // Scan feedback: true while either NM reports scanning or we're inside the
  // post-click grace window. Pinged from the scan button below.
  const scanPing = Variable(false)
  const scanBusy = net.wifi
    ? Variable.derive(
        [scanPing, bind(net.wifi, "scanning")],
        (p, s) => p || s,
      )
    : scanPing

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

  const apRows = () => {
    const w = net.wifi
    if (!w) return empty("No Wi-Fi device")
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
        })
      })
    return rows.length ? rows : empty("No networks found")
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
          // Guaranteed feedback: spin for at least 1.2 s on click in case NM
          // throttles the scan or `wifi.scanning` flips back too quickly.
          scanPing.set(true)
          GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1200, () => {
            scanPing.set(false)
            return GLib.SOURCE_REMOVE
          })
        },
        "Scan",
        scanBusy,
      )}
      {HeaderButton(Icon.settings, () => sh(["nm-connection-editor"]), "Settings")}
    </box>
  )

  // VPN rows: inline so each row binds to its own busy variable for the
  // optimistic spinner. Clicking toggles the connection via nmcli; the
  // service refreshes state when it returns.
  const vpnRow = (entry: VpnEntry) => {
    const busy = vpnBusyFor(entry.uuid)
    return (
      <button
        className={`dev-row ${entry.active ? "active" : ""}`}
        onClicked={tap(() => toggleVpn(entry))}
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
                label={Icon.vpn}
              />
            ),
          )}
          <box vertical halign={Gtk.Align.START} hexpand valign={Gtk.Align.CENTER}>
            <label
              className="dev-name"
              label={entry.name}
              halign={Gtk.Align.START}
              truncate
            />
            <label
              className="subtle"
              halign={Gtk.Align.START}
              label={bind(busy).as((b) =>
                b
                  ? entry.active
                    ? "Disconnecting…"
                    : "Connecting…"
                  : entry.active
                    ? "Connected"
                    : "Disconnected",
              )}
            />
          </box>
        </box>
      </button>
    )
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
        {Section("Ethernet", ethernet)}
        {Section(
          "Wi-Fi",
          ScrollList(
            net.wifi ? bind(net.wifi, "accessPoints").as(() => apRows()) : apRows(),
          ),
          wifiHeader,
        )}
        {Section(
          "VPN",
          ScrollList(
            bind(vpns).as((list) =>
              list.length ? list.map((v) => vpnRow(v)) : empty("No VPN configs"),
            ),
          ),
          vpnHeader,
        )}
      </box>
    ),
  })
}
