import { bind } from "astal"
import { Gtk } from "astal/gtk3"
import { Spinner } from "./Spinner"
import { tap } from "../utils/gtk"

// When `busy` is supplied the glyph is replaced with a spinner whenever the
// binding/Variable reads true. The inner box has a fixed min-size so the
// button doesn't shift horizontally between icon and spinner states.
export function HeaderButton(
  icon: string,
  onClicked: () => void,
  tooltip?: string,
  busy?: any,
) {
  if (!busy) {
    return (
      <button className="icon-btn" onClicked={tap(onClicked)} tooltipText={tooltip ?? ""}>
        <label label={icon} />
      </button>
    )
  }
  const binding = typeof busy.as === "function" ? busy : bind(busy)
  return (
    <button className="icon-btn" onClicked={tap(onClicked)} tooltipText={tooltip ?? ""}>
      <box
        className="icon-btn-content"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
      >
        {binding.as((b: boolean) =>
          b ? <Spinner active={busy} size={20} /> : <label label={icon} />,
        )}
      </box>
    </button>
  )
}
