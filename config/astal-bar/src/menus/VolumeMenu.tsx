import { Variable, bind } from "astal"
import { execAsync } from "astal/process"
import { Gtk } from "astal/gtk3"
import AstalWp from "gi://AstalWp"
import { Icon, MIC_ICONS, VOLUME_RAMP } from "../const/icons"
import { MENU } from "../const/menu"
import { defaultMicrophone, defaultSpeaker } from "../services/audio"
import {
  audioNameOf,
  endpointConnected,
  prettyAudioName,
  sortPriority,
} from "../services/audio-naming"
import { HeaderButton } from "../ui/HeaderButton"
import { ScrollList } from "../ui/ScrollList"
import { Section } from "../ui/Section"
import { tap } from "../utils/gtk"
import { pct, sh } from "../utils/shell"
import { MenuWindow } from "./MenuWindow"

function EndpointSlider(ep: any, onIcon: string, offIcon: string) {
  return (
    <box vertical>
      <label
        className="dev-name"
        label={audioNameOf(ep)}
        halign={Gtk.Align.START}
        truncate
      />
      <box className="vol-row">
        <button className="icon-btn" onClicked={tap(() => (ep.mute = !ep.mute))}>
          <label
            className="dev-icon"
            label={bind(ep, "mute").as((m: boolean) => (m ? offIcon : onIcon))}
          />
        </button>
        <slider
          hexpand
          min={0}
          max={1}
          step={0.01}
          value={bind(ep, "volume")}
          onDragged={({ value }: any) => (ep.volume = value)}
        />
        <label label={bind(ep, "volume").as(pct)} />
      </box>
    </box>
  )
}

// Two AstalWp quirks:
//   - set_is_default doesn't write the metadata → use wpctl.
//   - wpctl set-default only affects new streams → move each live stream too.
function deviceList(endpoints: any[], icon: string) {
  if (!endpoints?.length) return <box />
  const setDefault = async (ep: any) => {
    const id = String(ep.id)
    await sh(["wpctl", "set-default", id])
    const isSink = /Sink/i.test(ep.mediaClass ?? "")
    const listCmd = isSink ? "sink-inputs" : "source-outputs"
    const moveCmd = isSink ? "move-sink-input" : "move-source-output"
    try {
      const out = await execAsync(["pactl", "list", "short", listCmd])
      for (const line of out.split("\n")) {
        const stream = line.split(/\s+/)[0]
        if (stream) sh(["pactl", moveCmd, stream, id])
      }
    } catch {
      /* nothing to move */
    }
  }
  return (
    <box vertical>
      {[...endpoints]
        .sort((a, b) => {
          const an = prettyAudioName(a)
          const bn = prettyAudioName(b)
          const ap = sortPriority(a, an)
          const bp = sortPriority(b, bn)
          if (ap !== bp) return ap - bp
          return an.localeCompare(bn)
        })
        .map((ep) => {
          const dev = ep.device
          return (
            <button
              className={bind(ep, "isDefault").as(
                (d: boolean) => `dev-row ${d ? "active" : ""}`,
              )}
              visible={
                dev
                  ? bind(dev, "routes").as(
                      () => ep.isDefault || endpointConnected(ep),
                    )
                  : true
              }
              onClicked={tap(() => setDefault(ep))}
            >
              <box>
                <label
                  className="dev-icon"
                  label={icon}
                  valign={Gtk.Align.CENTER}
                />
                <box
                  vertical
                  halign={Gtk.Align.START}
                  hexpand
                  valign={Gtk.Align.CENTER}
                >
                  <label
                    className="dev-name"
                    label={audioNameOf(ep)}
                    halign={Gtk.Align.START}
                    truncate
                  />
                </box>
              </box>
            </button>
          )
        })}
    </box>
  )
}

export function VolumeMenu() {
  const audio = AstalWp.get_default()?.audio
  if (!audio) return <box />

  const speakerList = Variable.derive(
    [bind(audio, "speakers")],
    (sinks: any[]) => deviceList(sinks, VOLUME_RAMP.full),
  )
  const micList = Variable.derive(
    [bind(audio, "microphones")],
    (srcs: any[]) => deviceList(srcs, MIC_ICONS.on),
  )

  return MenuWindow({
    name: MENU.volume,
    klass: "audio",
    child: (
      <box className="audio-col" vertical>
        {Section(
          "Sound",
          <box vertical>
            {bind(defaultSpeaker()).as((sp: any) =>
              sp ? EndpointSlider(sp, VOLUME_RAMP.full, VOLUME_RAMP.mute) : <box />,
            )}
            {bind(defaultMicrophone()).as((mic: any) =>
              mic ? EndpointSlider(mic, MIC_ICONS.on, MIC_ICONS.off) : <box />,
            )}
          </box>,
          HeaderButton(Icon.settings, () => sh(["pwvucontrol"]), "Settings"),
        )}
        {Section("Output", ScrollList(bind(speakerList)))}
        {Section("Input", ScrollList(bind(micList)))}
      </box>
    ),
  })
}
