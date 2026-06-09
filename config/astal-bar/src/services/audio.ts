// AstalWp doesn't notify on default-speaker/-microphone, but per-endpoint
// notify::is-default does. Aggregate it into a Variable.
import { Variable } from "astal"
import AstalWp from "gi://AstalWp"
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
