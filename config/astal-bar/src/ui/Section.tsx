import type { Binding } from "astal"
import { Gtk } from "astal/gtk3"

// `body` may be a binding (e.g. a row that re-renders on a state change).
export function Section(
  title: string,
  body: JSX.Element | Binding<JSX.Element>,
  right?: JSX.Element,
) {
  return (
    <box className="section" vertical>
      <box className="section-head">
        <label
          className="section-title"
          label={title}
          hexpand
          halign={Gtk.Align.START}
        />
        {right ?? <box />}
      </box>
      {body}
    </box>
  )
}
