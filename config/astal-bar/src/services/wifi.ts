// NM swaps net.wifi for a new device object on suspend/resume; bindings to the
// old object go dead, so we re-subscribe on notify::wifi and republish into a
// single Variable. enabledView adds an optimistic intent so the menu switch
// doesn't flicker while NM cycles `enabled` bringing the radio up.
import { Variable } from "astal"
import AstalNetwork from "gi://AstalNetwork"
import GLib from "gi://GLib"

const net = AstalNetwork.get_default()

// ---- optimistic enabled intent ----
const intent = Variable<boolean | null>(null)
let timeoutId: number | null = null

function clearIntent() {
  if (timeoutId !== null) {
    GLib.source_remove(timeoutId)
    timeoutId = null
  }
  if (intent.get() !== null) intent.set(null)
}

export function setEnabledIntent(want: boolean, revertMs = 5000) {
  intent.set(want)
  if (timeoutId !== null) GLib.source_remove(timeoutId)
  timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, revertMs, () => {
    intent.set(null)
    timeoutId = null
    return GLib.SOURCE_REMOVE
  })
}

export type WifiState = {
  device: AstalNetwork.Wifi | null
  enabled: boolean
  ssid: string | null
  strength: number
  internet: AstalNetwork.Internet
  scanning: boolean
  accessPoints: AstalNetwork.AccessPoint[]
}

const WATCHED = [
  "enabled",
  "ssid",
  "strength",
  "internet",
  "scanning",
  "access-points",
] as const

function snapshot(w: AstalNetwork.Wifi | null): WifiState {
  return {
    device: w,
    enabled: w ? w.enabled : false,
    ssid: w ? w.ssid : null,
    strength: w ? w.strength : 0,
    internet: w ? w.internet : AstalNetwork.Internet.DISCONNECTED,
    scanning: w ? w.scanning : false,
    accessPoints: w ? w.accessPoints : [],
  }
}

export const wifiState = Variable<WifiState>(snapshot(net.wifi))

let watched: AstalNetwork.Wifi | null = null
let handlerIds: number[] = []

function attach() {
  const dev = net.wifi
  if (dev !== watched) {
    if (watched) for (const id of handlerIds) watched.disconnect(id)
    handlerIds = []
    watched = dev
    if (dev) {
      for (const prop of WATCHED) {
        handlerIds.push(
          dev.connect(`notify::${prop}`, () => {
            wifiState.set(snapshot(dev))
            if (prop === "enabled") {
              const want = intent.get()
              if (want !== null && dev.enabled === want) clearIntent()
            }
          }),
        )
      }
    }
  }
  wifiState.set(snapshot(dev))
}

net.connect("notify::wifi", attach)
attach()

// Intent-aware enabled view: the user's pending intent wins until NM settles.
export const enabledView: Variable<boolean> = Variable.derive(
  [intent, wifiState],
  (want, st) => (want !== null ? want : st.enabled),
)
