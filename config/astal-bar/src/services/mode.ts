// Device posture published by mode-daemon into $XDG_RUNTIME_DIR/mode-state
// (laptop | tablet | external). The monitor reference is held at module
// scope so GJS doesn't GC the listener.
import { Variable } from "astal"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import { readFile } from "../utils/sysfs"

const stateFile = `${GLib.get_user_runtime_dir()}/mode-state`

function read(): string {
  return (readFile(stateFile) ?? "laptop").trim() || "laptop"
}

export const deviceMode = Variable(read())
export const isTablet = Variable.derive(
  [deviceMode],
  (m: string) => m === "tablet",
)

let monitor: Gio.FileMonitor | null = null
try {
  monitor = Gio.File.new_for_path(stateFile).monitor(
    Gio.FileMonitorFlags.NONE,
    null,
  )
  monitor.connect("changed", () => deviceMode.set(read()))
} catch {}
