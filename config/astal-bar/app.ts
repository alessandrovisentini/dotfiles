import { App } from "astal/gtk3"
import style from "./style.scss"
import Bar, { monitorKey } from "./src/bar/Bar"
import {
  BluetoothMenu,
  BrightnessMenu,
  NetworkMenu,
  PowerMenu,
  VolumeMenu,
} from "./src/menus"

// One bar per monitor; keyed so we can recreate on add and destroy on remove.
const bars = new Map<string, any>()

function addBar(monitor: any) {
  const key = monitorKey(monitor)
  bars.get(key)?.destroy()
  bars.set(key, Bar(monitor))
}

function dropBar(monitor: any) {
  const key = monitorKey(monitor)
  bars.get(key)?.destroy()
  bars.delete(key)
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
  },
})
