import { Variable, bind } from "astal"
import { Gtk } from "astal/gtk3"
import AstalNetwork from "gi://AstalNetwork"
import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { enabledView, setEnabledIntent, wifiState } from "../services/wifi"
import {
  busyFor as vpnBusyFor,
  startVpnPolling,
  stopVpnPolling,
  toggleVpn,
  vpns,
  type VpnEntry,
} from "../services/vpn"
import { EmptyState } from "../ui/EmptyState"
import { HeaderButton } from "../ui/HeaderButton"
import { Row } from "../ui/Row"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { NEEDS_SECRETS, nmcli } from "../utils/nmcli"
import { notify } from "../utils/notify"
import { promptPassword } from "../utils/prompt"
import { useScanPing } from "../utils/scan"
import { wifiIcon } from "../utils/icons"
import { sh } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

export function NetworkMenu() {
  const net = AstalNetwork.get_default()

  // Per-SSID "connect in flight" state for the row spinners.
  const connectBusy = new Map<string, Variable<boolean>>()
  const busyFor = (ssid: string) => {
    let v = connectBusy.get(ssid)
    if (!v) {
      v = Variable(false)
      connectBusy.set(ssid, v)
    }
    return v
  }

  // Connect flow: plain nmcli first (covers open + saved networks). For a
  // new secured network that fails wanting secrets, prompt via rofi and
  // retry with the password; only if that still fails fall back to the
  // connection editor (enterprise networks need more than a passphrase).
  const connect = async (ssid: string, requiresPassword: boolean) => {
    const busy = busyFor(ssid)
    if (busy.get()) return
    busy.set(true)
    try {
      try {
        await nmcli(["device", "wifi", "connect", ssid])
        return
      } catch (e: any) {
        const msg = String(e?.message ?? e)
        if (!(requiresPassword && NEEDS_SECRETS.test(msg))) {
          notify(`Wi-Fi failed: ${ssid}`, msg, "network-wireless")
          return
        }
      }
      const pass = await promptPassword(`Wi-Fi: ${ssid}`)
      if (!pass) return
      try {
        await nmcli(["device", "wifi", "connect", ssid, "password", pass])
      } catch (e: any) {
        notify(`Wi-Fi failed: ${ssid}`, String(e?.message ?? e), "network-wireless")
        sh(["nm-connection-editor"])
      }
    } finally {
      busy.set(false)
    }
  }

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
        const busy = bind(busyFor(ap.ssid!))
        return Row({
          active,
          icon: wifiIcon(ap.strength),
          name: ap.ssid!,
          busy,
          status: busy.as((b) => {
            if (b) return "Connecting…"
            if (active) return "Connected"
            return ap.requiresPassword ? "Secured" : "Open"
          }),
          onClicked: () => connect(ap.ssid!, ap.requiresPassword),
        })
      })
    return rows.length ? rows : EmptyState("No networks found")
  }

  // AP rows rebuild only while the menu is visible: wifiState updates on
  // every strength notify, which would otherwise churn up to 20 rows in the
  // background all day.
  const apList = Variable<JSX.Element | JSX.Element[]>(apRows())

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

  const win = MenuWindow({
    name: MENU.network,
    klass: "net",
    child: (
      <box vertical>
        {Section("Ethernet", bind(net, "primary").as(() => ethernetRow()))}
        {Section("Wi-Fi", ScrollList(bind(apList)), wifiHeader)}
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

  // Live state only while open: AP-row rebuilds resume (with one immediate
  // refresh) and the VPN nmcli poll runs; both stop when the menu hides.
  let unsubAps: (() => void) | null = null
  win.connect("notify::visible", () => {
    if (win.visible) {
      apList.set(apRows())
      unsubAps ??= wifiState.subscribe(() => apList.set(apRows()))
      startVpnPolling()
    } else {
      unsubAps?.()
      unsubAps = null
      stopVpnPolling()
    }
  })

  return win
}
