import { Variable, bind } from "astal"
import AstalWp from "gi://AstalWp"
import { MENU } from "../enums/menu"
import { defaultSpeaker } from "../services/audio"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"
import { volumeIcon } from "../utils/icons"
import { pct } from "../utils/shell"

export function Volume() {
  const audio = AstalWp.get_default()?.audio
  if (!audio) return <box />
  return (
    <button
      className="bar-button"
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
            <label label={bind(sp, "volume").as(pct)} />
          </box>
        ) : (
          <box />
        ),
      )}
    </button>
  )
}
