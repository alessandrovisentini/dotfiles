// Hardware-specific audio endpoint labels, filtering and ordering.
import { bind } from "astal"
import AstalWp from "gi://AstalWp"
import { AudioPriority } from "../enums/audio"

export function isIntegratedAudio(ep: any): boolean {
  return /Smart Sound|HDA Intel|HD Audio|Tiger Lake|Realtek/i.test(
    ep?.device?.description ?? "",
  )
}

// The analog node's name doesn't flip Speaker↔Headphones; route availability does.
export function headphonesPluggedIn(ep: any): boolean {
  const hp = (ep?.device?.outputRoutes ?? []).find((r: any) =>
    /head(phone|set)/i.test(r.description ?? ""),
  )
  return hp?.available === AstalWp.Available.YES
}

export function prettyAudioName(ep: any): string {
  const raw = (ep?.description ?? ep?.name ?? "").trim()

  if (/HDMI|DisplayPort/i.test(raw)) {
    const n = raw.match(/(\d+)/)
    return n ? `HDMI ${n[1]}` : "HDMI"
  }

  if (isIntegratedAudio(ep)) {
    if (/microphone|\bmic\b/i.test(raw)) {
      return /digital/i.test(raw)
        ? "Integrated Digital Mic"
        : "Integrated Microphone"
    }
    if (/head(phone|set)|speaker/i.test(raw)) {
      return headphonesPluggedIn(ep) ? "Headphones" : "Integrated Speakers"
    }
    return raw
  }

  const dev = (ep?.device?.description ?? "").trim()
  if (!dev) return raw
  const port = raw.startsWith(dev) ? raw.slice(dev.length).trim() : ""
  const inMatch = port.match(/^Input\s+(\d+)/i)
  if (inMatch) return `${dev} · In ${inMatch[1]}`
  const outMatch = port.match(/^Output\s+(\d+)/i)
  if (outMatch) return `${dev} · Out ${outMatch[1]}`
  return dev
}

// Reactive name; re-evaluates on port changes.
export function audioNameOf(ep: any): any {
  return ep?.device
    ? bind(ep.device, "routes").as(() => prettyAudioName(ep))
    : prettyAudioName(ep)
}

// Lower priority = higher in the list. External devices share the trailing bucket.
export function sortPriority(ep: any, name: string): number {
  if (!isIntegratedAudio(ep)) return AudioPriority.Other
  if (/^Integrated Speakers$/.test(name)) return AudioPriority.Integrated
  if (/^Integrated Microphone$/.test(name)) return AudioPriority.Integrated
  if (/^Headphones$/.test(name)) return AudioPriority.Headphones
  if (/^Integrated Digital Mic$/.test(name)) return AudioPriority.Headphones
  const hdmi = name.match(/^HDMI\s+(\d+)/)
  if (hdmi) return AudioPriority.HdmiBase + Number(hdmi[1])
  return AudioPriority.External
}

// Only HDMI/DP report a reliable cable-presence flag; everything else passes.
export function endpointConnected(ep: any): boolean {
  const desc = (ep?.description ?? "").trim()
  if (!/HDMI|DisplayPort/i.test(desc)) return true
  const dev = ep?.device
  if (!dev) return true
  const port = (dev.outputRoutes ?? []).find(
    (r: any) => r.description && desc.endsWith(r.description.trim()),
  )
  return !port || port.available !== AstalWp.Available.NO
}
