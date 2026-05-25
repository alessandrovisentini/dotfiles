import { Variable, bind } from "astal"
import AstalWp from "gi://AstalWp"
import { MENU } from "../const/menu"
import { defaultSpeaker } from "../services/audio"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"
import { volumeIcon } from "../utils/icons"
import { pct } from "../utils/shell"

// Flatten "default speaker → its mute" into a single observable Variable.
function speakerMute(): Variable<boolean> {
  const v = Variable(false)
  let conn: { ep: any; id: number } | null = null
  defaultSpeaker().subscribe((sp: any) => {
    if (conn) {
      try { conn.ep.disconnect(conn.id) } catch {}
      conn = null
    }
    if (!sp) { v.set(false); return }
    v.set(!!sp.mute)
    conn = {
      ep: sp,
      id: sp.connect("notify::mute", () => v.set(!!sp.mute)),
    }
  })
  return v
}

export function Volume() {
  const audio = AstalWp.get_default()?.audio
  if (!audio) return <box />
  const mute = speakerMute()
  return (
    <button
      className={bind(mute).as((m) =>
        `bar-button ${m ? "state-vol-mute" : "state-vol"}`,
      )}
      onClicked={tap(() => toggleMenu(MENU.volume))}
      tooltipText="Sound"
    >
      {bind(defaultSpeaker()).as((sp: any) =>
        sp ? (
          <box>
            <label
              className="module-icon"
              label={Variable.derive(
                [bind(sp, "volume"), bind(sp, "mute")],
                (v: number, m: boolean) => volumeIcon(v, m),
              )()}
            />
            <label
              label={bind(sp, "volume").as(pct)}
              visible={bind(sp, "mute").as((m) => !m)}
            />
          </box>
        ) : (
          <box />
        ),
      )}
    </button>
  )
}
