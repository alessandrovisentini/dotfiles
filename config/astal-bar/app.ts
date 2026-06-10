import { App } from "astal/gtk3"
import style from "./style.scss"
import Bar from "./src/bar/Bar"
import { startMetrics, stopMetrics } from "./src/services/metrics"
import {
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
const bars = new Map<any, any>()

function addBar(monitor: any) {
  bars.get(monitor)?.destroy()
  bars.set(monitor, Bar(monitor))
}

function dropBar(monitor: any) {
  bars.get(monitor)?.destroy()
  bars.delete(monitor)
}

App.start({
  instanceName: "astal-bar",
  css: style,
  main() {
    App.get_monitors().forEach(addBar)
    App.connect("monitor-added", (_a: any, m: any) => addBar(m))
    App.connect("monitor-removed", (_a: any, m: any) => dropBar(m))

    PowerMenu()
    NetworkMenu()
    BluetoothMenu()
    VolumeMenu()
    BrightnessMenu()
    // Sample system metrics only while the performance menu is open.
    const perfMenu = PowerProfileMenu()
    perfMenu.connect("notify::visible", (w: any) =>
      w.visible ? startMetrics() : stopMetrics(),
    )
  },
})
