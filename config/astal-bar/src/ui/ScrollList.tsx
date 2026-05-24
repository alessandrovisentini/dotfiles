import { Gtk } from "astal/gtk3"

export function ScrollList(child: any) {
  return (
    <scrollable
      className="scroll-list"
      hscroll={Gtk.PolicyType.NEVER}
      vscroll={Gtk.PolicyType.AUTOMATIC}
      propagateNaturalHeight
      maxContentHeight={300}
    >
      <box vertical>{child}</box>
    </scrollable>
  )
}
