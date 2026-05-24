import { Gtk } from "astal/gtk3"

export function Section(title: string, body: any, right?: any) {
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
