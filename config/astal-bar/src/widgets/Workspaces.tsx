import { Variable, bind } from "astal"
import { Gdk } from "astal/gtk3"
import { Icon } from "../const/icons"
import {
  addWorkspace,
  focusWorkspace,
  focusWorkspaceByName,
  outputNameFor,
  outputs,
  workspaces,
} from "../services/sway"
import { closeAllMenus } from "../services/menu"
import type { SwayWorkspace } from "../types/sway"
import { tap } from "../utils/gtk"
import { own } from "../utils/reactive"

// Per-output workspace list (matches the bar to its output reactively).
export function Workspaces({ gdkmonitor }: { gdkmonitor?: Gdk.Monitor } = {}) {
  const list = Variable.derive(
    [bind(workspaces), bind(outputs)],
    (wss: SwayWorkspace[], outs) => {
      const output = gdkmonitor ? outputNameFor(outs, gdkmonitor) : undefined
      const here = output ? wss.filter((ws) => ws.output === output) : wss
      return [...here].sort((a, b) => a.num - b.num)
    },
  )
  return (
    <box className="workspaces" setup={own(list)}>
      {bind(list).as((wss) =>
        wss.map((ws) => (
          <button
            className={`ws ${
              ws.focused ? "focused" : ws.visible ? "visible" : ""
            } ${ws.urgent ? "urgent" : ""}`}
            onClicked={tap(() => {
              closeAllMenus()
              // Named workspaces report num = -1.
              if (ws.num >= 1) focusWorkspace(ws.num)
              else focusWorkspaceByName(ws.name)
            })}
          >
            <label label={ws.num >= 1 ? String(ws.num) : ws.name} />
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
