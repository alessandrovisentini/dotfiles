import { App, Gdk, Gtk } from "astal/gtk3"
import style from "./style.scss"
import Bar from "./src/bar/Bar"
import {
  BatteryMenu,
  BluetoothMenu,
  BrightnessMenu,
  NetworkMenu,
  PowerMenu,
  PowerProfileMenu,
  VolumeMenu,
} from "./src/menus"

// One bar per monitor. Keyed by the Gdk.Monitor object, not its geometry:
// on hotplug GDK emits monitor-added before sway positions the output, so
// geometry-based keys collide at 0,0 and clobber the existing monitor's bar.
const bars = new Map<Gdk.Monitor, Gtk.Widget>()

function addBar(monitor: Gdk.Monitor) {
  bars.get(monitor)?.destroy()
  bars.set(monitor, Bar(monitor))
}

function dropBar(monitor: Gdk.Monitor) {
  bars.get(monitor)?.destroy()
  bars.delete(monitor)
}

App.start({
  instanceName: "astal-bar",
  css: style,
  main() {
    App.get_monitors().forEach(addBar)
    App.connect("monitor-added", (_app, m: Gdk.Monitor) => addBar(m))
    App.connect("monitor-removed", (_app, m: Gdk.Monitor) => dropBar(m))

    // Menus are global singletons; each wires its own visibility-gated
    // polling (metrics, VPN) internally.
    PowerMenu()
    NetworkMenu()
    BluetoothMenu()
    VolumeMenu()
    BrightnessMenu()
    PowerProfileMenu()
    BatteryMenu()
  },
})
