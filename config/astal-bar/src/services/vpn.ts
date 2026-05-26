// VPN connections aren't exposed by AstalNetwork's bindings, so we drive
// them through nmcli. The service keeps a list of configured VPN/WireGuard
// connections plus per-UUID busy state for the menu's spinners. A slow
// poll catches state changes that originate outside the menu (CLI toggles,
// auto-connect, drops); each user action triggers an immediate refresh on
// top of that.
//
// nmcli can't fetch agent-owned secrets (password-flags=1) without a NM
// secret agent, which sway sessions usually don't run. When the first
// activation attempt fails with "No valid secrets" we prompt the user via
// rofi and retry with a tmpfs `passwd-file`. Errors are surfaced through
// notify-send so the row doesn't fail silently.
import { Variable } from "astal"
import { execAsync } from "astal/process"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

export type VpnEntry = {
  name: string
  uuid: string
  active: boolean
}

export const vpns = Variable<VpnEntry[]>([])

const busyMap = new Map<string, Variable<boolean>>()
let busyCount = 0
export function busyFor(uuid: string): Variable<boolean> {
  let v = busyMap.get(uuid)
  if (!v) {
    v = Variable(false)
    busyMap.set(uuid, v)
  }
  return v
}

// nmcli -t escapes ':' inside fields as '\:'. Split on unescaped ':' only
// so names like "Work: prod" round-trip cleanly.
function splitTerse(line: string): string[] {
  const out: string[] = []
  let cur = ""
  for (let i = 0; i < line.length; i++) {
    const ch = line[i]
    if (ch === "\\" && line[i + 1] === ":") {
      cur += ":"
      i++
    } else if (ch === ":") {
      out.push(cur)
      cur = ""
    } else {
      cur += ch
    }
  }
  out.push(cur)
  return out
}

async function fetchVpns(): Promise<VpnEntry[]> {
  try {
    const [all, active] = await Promise.all([
      execAsync(["nmcli", "-t", "-f", "NAME,UUID,TYPE", "connection", "show"]),
      execAsync(["nmcli", "-t", "-f", "UUID", "connection", "show", "--active"]),
    ])
    const activeSet = new Set(
      active.split("\n").map((s) => s.trim()).filter(Boolean),
    )
    return all
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean)
      .map(splitTerse)
      .filter((p) => p.length >= 3)
      .map((p) => ({
        name: p.slice(0, p.length - 2).join(":"),
        uuid: p[p.length - 2],
        type: p[p.length - 1],
      }))
      .filter((c) => c.type === "vpn" || c.type === "wireguard")
      .map((c) => ({ name: c.name, uuid: c.uuid, active: activeSet.has(c.uuid) }))
      .sort((a, b) => a.name.localeCompare(b.name))
  } catch {
    return []
  }
}

export async function refreshVpns() {
  vpns.set(await fetchVpns())
}

function notify(summary: string, body: string) {
  execAsync([
    "notify-send",
    "-a",
    "astal-bar",
    "-i",
    "network-vpn",
    summary,
    body,
  ]).catch(() => {})
}

// rofi -password reads no entries from stdin; sh -c gives us an empty pipe
// so rofi doesn't block on a terminal-less invocation.
async function promptPassword(name: string): Promise<string | null> {
  const safe = name.replace(/"/g, '\\"')
  try {
    const out = await execAsync([
      "sh",
      "-c",
      `printf '' | rofi -dmenu -password -p "VPN: ${safe}" -lines 0`,
    ])
    const pass = out.replace(/\n$/, "")
    return pass.length ? pass : null
  } catch {
    return null
  }
}

// Write the secret to a tmpfs file (XDG_RUNTIME_DIR) with mode 600, then
// unlink immediately after nmcli reads it. Avoids persisting plaintext to
// the home directory and keeps the lifetime as short as possible.
async function upWithPassword(
  uuid: string,
  password: string,
): Promise<{ ok: boolean; err?: string }> {
  const dir = GLib.getenv("XDG_RUNTIME_DIR") ?? "/tmp"
  const path = `${dir}/.astal-vpn-${uuid}`
  try {
    GLib.file_set_contents(path, `vpn.secrets.password:${password}\n`)
    const f = Gio.File.new_for_path(path)
    const info = new Gio.FileInfo()
    info.set_attribute_uint32("unix::mode", 0o600)
    f.set_attributes_from_info(info, Gio.FileQueryInfoFlags.NONE, null)
  } catch (e: any) {
    return { ok: false, err: String(e?.message ?? e) }
  }
  try {
    await execAsync([
      "nmcli",
      "connection",
      "up",
      "uuid",
      uuid,
      "passwd-file",
      path,
    ])
    return { ok: true }
  } catch (e: any) {
    return { ok: false, err: String(e?.message ?? e) }
  } finally {
    try {
      GLib.unlink(path)
    } catch {}
  }
}

const NEEDS_SECRETS = /No valid secrets|secrets were required|not given/i

async function bringUp(entry: VpnEntry): Promise<void> {
  try {
    await execAsync(["nmcli", "connection", "up", "uuid", entry.uuid])
    return
  } catch (e: any) {
    const msg = String(e?.message ?? e)
    if (!NEEDS_SECRETS.test(msg)) {
      notify(`VPN failed: ${entry.name}`, msg)
      return
    }
  }
  const pass = await promptPassword(entry.name)
  if (!pass) return
  const res = await upWithPassword(entry.uuid, pass)
  if (!res.ok) notify(`VPN failed: ${entry.name}`, res.err ?? "")
}

async function bringDown(entry: VpnEntry): Promise<void> {
  try {
    await execAsync(["nmcli", "connection", "down", "uuid", entry.uuid])
  } catch (e: any) {
    notify(`VPN failed: ${entry.name}`, String(e?.message ?? e))
  }
}

export async function toggleVpn(entry: VpnEntry) {
  const busy = busyFor(entry.uuid)
  if (busy.get()) return
  busy.set(true)
  busyCount++
  try {
    // Optimistic: flip the active flag locally so the row reflects intent
    // while nmcli (and any auth agent) catches up.
    vpns.set(
      vpns.get().map((v) =>
        v.uuid === entry.uuid ? { ...v, active: !v.active } : v,
      ),
    )
    if (entry.active) await bringDown(entry)
    else await bringUp(entry)
    await refreshVpns()
  } finally {
    busy.set(false)
    busyCount--
  }
}

refreshVpns()
// Skip background refresh while a toggle is in flight so the optimistic
// state we just wrote doesn't get clobbered mid-transition.
vpns.poll(8000, async () => (busyCount > 0 ? vpns.get() : fetchVpns()))
