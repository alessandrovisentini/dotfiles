import { Gtk } from "astal/gtk3"
import { Spinner } from "./Spinner"
import { tap } from "../utils/gtk"
import { toBinding, type Reactive } from "../utils/reactive"

// When `busy` is supplied the glyph is replaced with a spinner whenever it
// reads true. The inner box has a fixed min-size so the button doesn't shift
// horizontally between icon and spinner states.
export function HeaderButton(
  icon: string,
  onClicked: () => void,
  tooltip?: string,
  busy?: Reactive<boolean>,
) {
  if (!busy) {
    return (
      <button className="icon-btn" onClicked={tap(onClicked)} tooltipText={tooltip ?? ""}>
        <label label={icon} />
      </button>
    )
  }
  return (
    <button className="icon-btn" onClicked={tap(onClicked)} tooltipText={tooltip ?? ""}>
      <box
        className="icon-btn-content"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
      >
        {toBinding(busy).as((b) =>
          b ? <Spinner active={busy} size={20} /> : <label label={icon} />,
        )}
      </box>
    </button>
  )
}
