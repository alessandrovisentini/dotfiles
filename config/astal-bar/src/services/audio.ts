// AstalWp doesn't notify on default-speaker/-microphone, but per-endpoint
// notify::is-default does. Aggregate it into a Variable.
import { Variable } from "astal"
import AstalWp from "gi://AstalWp"
import type { EndpointKind } from "../types/audio"

function trackDefault(audio: any, kind: EndpointKind): Variable<any> {
  const getList = () =>
    kind === "speaker" ? audio.get_speakers() : audio.get_microphones()
  const initial =
    kind === "speaker" ? audio.defaultSpeaker : audio.defaultMicrophone
  const v = Variable<any>(initial)
  let conns: Array<{ ep: any; id: number }> = []
  const reattach = () => {
    for (const c of conns) try { c.ep.disconnect(c.id) } catch {}
    conns = []
    for (const ep of getList()) {
      const id = ep.connect("notify::is-default", () => {
        if (ep.isDefault) v.set(ep)
      })
      conns.push({ ep, id })
    }
    const cur = getList().find((e: any) => e.isDefault)
    if (cur && cur !== v.get()) v.set(cur)
  }
  reattach()
  audio.connect(`${kind}-added`, reattach)
  audio.connect(`${kind}-removed`, reattach)
  return v
}

let _defSpeaker: Variable<any> | null = null
let _defMic: Variable<any> | null = null

export function defaultSpeaker(): Variable<any> {
  if (_defSpeaker) return _defSpeaker
  const audio = AstalWp.get_default()?.audio
  return (_defSpeaker = audio
    ? trackDefault(audio, "speaker")
    : Variable<any>(null))
}

export function defaultMicrophone(): Variable<any> {
  if (_defMic) return _defMic
  const audio = AstalWp.get_default()?.audio
  return (_defMic = audio
    ? trackDefault(audio, "microphone")
    : Variable<any>(null))
}
