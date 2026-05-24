import { Variable, bind } from "astal"
import GLib from "gi://GLib"

export function Clock() {
  const time = Variable("").poll(
    1000,
    () => GLib.DateTime.new_now_local().format("%a %-d %b   %H:%M") ?? "",
  )
  return (
    <box className="chip clock">
      <label label={bind(time)} />
    </box>
  )
}
