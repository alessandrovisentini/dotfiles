import { execAsync } from "astal/process"

// Desktop notification via notify-send; menus use this to surface command
// failures (the row UI has nowhere to show an error message).
export function notify(summary: string, body: string, icon = "dialog-information") {
  execAsync(["notify-send", "-a", "astal-bar", "-i", icon, summary, body]).catch(
    () => {},
  )
}
