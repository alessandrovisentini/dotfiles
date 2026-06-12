// AstalWp doesn't notify on default-speaker/-microphone, but per-endpoint
// notify::is-default does. Aggregate it into a Variable.
import { Variable } from "astal"
import AstalWp from "gi://AstalWp"
import { prettyAudioName } from "./audio-naming"
import type { EndpointKind } from "../types/audio"

type Endpoint = AstalWp.Endpoint

function trackDefault(
  audio: AstalWp.Audio,
  kind: EndpointKind,
): Variable<Endpoint | null> {
  const getList = () =>
    kind === "speaker" ? audio.get_speakers() : audio.get_microphones()
  const initial =
    kind === "speaker" ? audio.defaultSpeaker : audio.defaultMicrophone
  const v = Variable<Endpoint | null>(initial)
  let conns: Array<{ ep: Endpoint; id: number }> = []
  const reattach = () => {
    for (const c of conns) try { c.ep.disconnect(c.id) } catch {}
    conns = []
    for (const ep of getList()) {
      const id = ep.connect("notify::is-default", () => {
        if (ep.isDefault) v.set(ep)
      })
      conns.push({ ep, id })
    }
    const cur = getList().find((e) => e.isDefault)
    if (cur && cur !== v.get()) v.set(cur)
  }
  reattach()
  audio.connect(`${kind}-added`, reattach)
  audio.connect(`${kind}-removed`, reattach)
  return v
}

let _defSpeaker: Variable<Endpoint | null> | null = null
let _defMic: Variable<Endpoint | null> | null = null

export function defaultSpeaker(): Variable<Endpoint | null> {
  if (_defSpeaker) return _defSpeaker
  const audio = AstalWp.get_default()?.audio
  return (_defSpeaker = audio
    ? trackDefault(audio, "speaker")
    : Variable<Endpoint | null>(null))
}

export function defaultMicrophone(): Variable<Endpoint | null> {
  if (_defMic) return _defMic
  const audio = AstalWp.get_default()?.audio
  return (_defMic = audio
    ? trackDefault(audio, "microphone")
    : Variable<Endpoint | null>(null))
}

// Volume/mute/name of the default endpoint of a kind, flattened across
// endpoint swaps into one singleton Variable per kind. Widgets bind these
// directly (static widgets, label-only updates) instead of re-rendering
// subtrees per default change: widget-creating `.as()` transforms get extra
// get() calls from astal's binding plumbing whose results are discarded,
// orphaning widgets (GJS "sweeping phase of GC" criticals). It also means
// bar widgets hold no per-instance subscriptions (per-bar leaks on hotplug).
export type EndpointState = { volume: number; mute: boolean; name: string } | null

function trackState(def: Variable<Endpoint | null>): Variable<EndpointState> {
  const v = Variable<EndpointState>(null)
  let ep: Endpoint | null = null
  let conns: Array<{ obj: any; id: number }> = []
  const sync = () =>
    v.set(
      ep ? { volume: ep.volume, mute: !!ep.mute, name: prettyAudioName(ep) } : null,
    )
  const attach = (next: Endpoint | null) => {
    for (const c of conns) try { c.obj.disconnect(c.id) } catch {}
    conns = []
    ep = next
    if (ep) {
      conns.push({ obj: ep, id: ep.connect("notify::volume", sync) })
      conns.push({ obj: ep, id: ep.connect("notify::mute", sync) })
      // Speaker↔Headphones naming flips on route availability.
      const dev = ep.device
      if (dev) conns.push({ obj: dev, id: dev.connect("notify::routes", sync) })
    }
    sync()
  }
  attach(def.get())
  def.subscribe(attach)
  return v
}

let _speakerState: Variable<EndpointState> | null = null
let _micState: Variable<EndpointState> | null = null

export function speakerState(): Variable<EndpointState> {
  return (_speakerState ??= trackState(defaultSpeaker()))
}

export function microphoneState(): Variable<EndpointState> {
  return (_micState ??= trackState(defaultMicrophone()))
}
