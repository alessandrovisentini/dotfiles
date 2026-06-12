import { bind } from "astal"
import { Gtk } from "astal/gtk3"
import { MENU } from "../const/menu"
import { speakerState } from "../services/audio"
import { toggleMenu } from "../services/menu"
import { tap } from "../utils/gtk"
import { volumeIcon } from "../utils/icons"
import { pct } from "../utils/shell"

export function Volume() {
  const st = speakerState()
  return (
    <button
      className={bind(st).as((s) =>
        `bar-button ${s?.mute ? "state-vol-mute" : "state-vol"}`,
      )}
      visible={bind(st).as((s) => s !== null)}
      onClicked={tap((self) => toggleMenu(MENU.volume, self))}
      tooltipText="Sound"
    >
      {/* halign center: the button keeps a 28px touch target, wider than
          the lone mute glyph, so center the content or it packs left. */}
      <box halign={Gtk.Align.CENTER}>
        <label
          className="module-icon"
          label={bind(st).as((s) => volumeIcon(s?.volume ?? 0, s?.mute ?? true))}
        />
        <label
          label={bind(st).as((s) => pct(s?.volume ?? 0))}
          visible={bind(st).as((s) => !!s && !s.mute)}
        />
      </box>
    </button>
  )
}
