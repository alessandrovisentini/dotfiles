// Workspace + output state driven from Sway IPC.
import { Variable } from "astal"
import { execAsync, subprocess } from "astal/process"
import type { SwayOutput, SwayWorkspace } from "../types/sway"

export const workspaces = Variable<SwayWorkspace[]>([])
export const outputs = Variable<SwayOutput[]>([])

function refreshWorkspaces() {
  execAsync(["swaymsg", "-t", "get_workspaces"])
    .then((out) => {
      try {
        workspaces.set(JSON.parse(out))
      } catch (_e) {}
    })
    .catch(() => {})
}

function refreshOutputs() {
  execAsync(["swaymsg", "-t", "get_outputs"])
    .then((out) => {
      try {
        outputs.set(JSON.parse(out))
      } catch (_e) {}
    })
    .catch(() => {})
}

refreshWorkspaces()
refreshOutputs()

// Re-query on every change; cheap and always consistent.
subprocess(
  ["swaymsg", "-t", "subscribe", "-m", '["workspace"]'],
  () => refreshWorkspaces(),
  () => {},
)
subprocess(
  ["swaymsg", "-t", "subscribe", "-m", '["output"]'],
  () => {
    refreshOutputs()
    refreshWorkspaces()
  },
  () => {},
)

export function focusWorkspace(num: number) {
  execAsync(["swaymsg", "workspace", "number", String(num)]).catch(() => {})
}

// Create + focus a new workspace. Number is global-max+1 so it never collides
// across outputs. Sway auto-creates the workspace on focus.
export function addWorkspace() {
  const wss = workspaces.get()
  const max = wss.reduce((m, ws) => (ws.num > m ? ws.num : m), 0)
  focusWorkspace(max + 1)
}

// Resolve a Gdk.Monitor to its sway output name by matching geometry origin.
// Returns undefined when outputs haven't loaded or no match exists.
export function outputNameFor(monitor: any): string | undefined {
  const x = monitor?.geometry?.x ?? 0
  const y = monitor?.geometry?.y ?? 0
  return outputs.get().find((o) => o.rect?.x === x && o.rect?.y === y)?.name
}
