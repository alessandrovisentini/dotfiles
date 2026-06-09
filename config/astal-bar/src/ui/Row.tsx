import { Gtk } from "astal/gtk3"
import type { RowProps } from "../types/ui"
import { Spinner } from "./Spinner"
import { tap } from "../utils/gtk"
import { toBinding } from "../utils/reactive"

// Generic device/AP row: icon (or spinner while busy) + name + optional status
// sub-label + optional trailing action, with an `active` highlight. Every prop
// accepts a static value or a Binding.
export function Row(opts: RowProps) {
  const active = toBinding(opts.active ?? false)
  const busy = opts.busy
  // The spinner sits in a `.dev-icon` box so the row doesn't reflow between
  // glyph and spinner. Without busy, render a plain label (no per-render .as).
  const icon = busy ? (
    toBinding(busy).as((b) =>
      b ? (
        <box className="dev-icon" valign={Gtk.Align.CENTER}>
          <Spinner active={busy} size={22} />
        </box>
      ) : (
        <label className="dev-icon" valign={Gtk.Align.CENTER} label={opts.icon} />
      ),
    )
  ) : (
    <label className="dev-icon" valign={Gtk.Align.CENTER} label={opts.icon} />
  )
  return (
    <button
      className={active.as((a) => `dev-row ${a ? "active" : ""}`)}
      visible={opts.visible ?? true}
      onClicked={tap(() => opts.onClicked?.())}
    >
      <box>
        {icon}
        <box vertical halign={Gtk.Align.START} hexpand valign={Gtk.Align.CENTER}>
          <label className="dev-name" label={opts.name} halign={Gtk.Align.START} truncate />
          {opts.status != null ? (
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
