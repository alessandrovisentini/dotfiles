import { Gtk } from "astal/gtk3"

// Centered placeholder shown by menus when their list has no rows.
export function EmptyState(text: string) {
  return (
    <box
      className="notif-empty"
      hexpand
      vexpand
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
    >
      <label className="subtle" label={text} />
    </box>
  )
}
