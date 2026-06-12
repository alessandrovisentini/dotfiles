import { Variable, bind } from "astal"
import GLib from "gi://GLib"

// One shared ticker for every bar instance — a per-bar poll would keep
// running after its bar is destroyed on monitor unplug.
const time = Variable("").poll(
  1000,
  () => GLib.DateTime.new_now_local().format("%a %-d %b   %H:%M:%S") ?? "",
)

export function Clock() {
  return (
    <box className="chip clock">
      <label label={bind(time)} />
    </box>
  )
}
