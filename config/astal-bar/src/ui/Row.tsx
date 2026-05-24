import { Gtk } from "astal/gtk3"
import type { RowProps } from "../types/ui"
import { tap } from "../utils/gtk"

export function Row(opts: RowProps) {
  return (
    <button
      className={`dev-row ${opts.active ? "active" : ""}`}
      visible={opts.visible ?? true}
      onClicked={tap(() => opts.onClicked?.())}
    >
      <box>
        <label className="dev-icon" label={opts.icon} valign={Gtk.Align.CENTER} />
        <box vertical halign={Gtk.Align.START} hexpand valign={Gtk.Align.CENTER}>
          <label className="dev-name" label={opts.name} halign={Gtk.Align.START} truncate />
          {opts.status ? (
            <label className="subtle" label={opts.status} halign={Gtk.Align.START} />
          ) : (
            <box />
          )}
        </box>
        {opts.action ?? <box />}
      </box>
    </button>
  )
}
