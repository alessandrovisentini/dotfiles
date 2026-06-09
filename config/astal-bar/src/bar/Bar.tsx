import { App, Astal, Gdk, Gtk } from "astal/gtk3"
import {
  Battery,
  Bluetooth,
  Brightness,
  Clock,
  Network,
  Notifications,
  Osk,
  Power,
  SysTray,
  Volume,
  Workspaces,
} from "../widgets"
import { hasTouch } from "../utils/hardware"
import { trayHasItems } from "../widgets/SysTray"

// Unique per window. Geometry can't be the id: it's 0,0 until sway positions
// the output, and connector isn't reliably populated on GDK3/Wayland.
let barSeq = 0

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
  const name = `bar-${barSeq++}`
  return (
    <window
      className="Bar"
      name={name}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={App}
    >
      <centerbox>
        <box halign={Gtk.Align.START}>
          <box className="cluster">
            <Power />
          </box>
          <box className="cluster">
            <Workspaces gdkmonitor={gdkmonitor} />
          </box>
        </box>
        <box className="cluster" halign={Gtk.Align.CENTER}>
          <Clock />
        </box>
        <box halign={Gtk.Align.END}>
          <box className="cluster" visible={hasTouch ? true : trayHasItems}>
            <SysTray />
            {hasTouch && <Osk />}
          </box>
          <box className="cluster">
            <Network />
            <Bluetooth />
            <Volume />
            <Brightness />
            <Battery />
            <Notifications />
          </box>
        </box>
      </centerbox>
    </window>
  )
}
