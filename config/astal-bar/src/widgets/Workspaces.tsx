import { Variable, bind } from "astal"
import { Gdk } from "astal/gtk3"
import { Icon } from "../const/icons"
import { addWorkspace, focusWorkspace, outputs, workspaces } from "../services/sway"
import { closeAllMenus } from "../services/menu"
import { tap } from "../utils/gtk"

// Per-output workspace list (matches the bar to its output reactively).
export function Workspaces({ gdkmonitor }: { gdkmonitor?: Gdk.Monitor } = {}) {
  const ownOutput = Variable.derive([bind(outputs)], (outs: any[]) => {
    if (!gdkmonitor) return undefined
    const x = gdkmonitor?.geometry?.x ?? 0
    const y = gdkmonitor?.geometry?.y ?? 0
    return outs.find((o) => o.rect?.x === x && o.rect?.y === y)?.name
  })
  const list = Variable.derive(
    [bind(workspaces), bind(ownOutput)],
    (wss: any[], output: string | undefined) => {
      const here = output ? wss.filter((ws) => ws.output === output) : wss
      return [...here].sort((a, b) => a.num - b.num)
    },
  )
  return (
    <box className="workspaces">
      {bind(list).as((wss: any[]) =>
        wss.map((ws) => (
          <button
            className={`ws ${
              ws.focused ? "focused" : ws.visible ? "visible" : ""
            } ${ws.urgent ? "urgent" : ""}`}
            onClicked={tap(() => {
              closeAllMenus()
              focusWorkspace(ws.num)
            })}
          >
            <label label={String(ws.num)} />
          </button>
        )),
      )}
      <button
        className="ws ws-add"
        tooltipText="New workspace"
        onClicked={tap(() => {
          closeAllMenus()
          addWorkspace()
        })}
      >
        <label label={Icon.add} />
      </button>
    </box>
  )
}
