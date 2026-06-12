import { execAsync } from "astal/process"

// Masked secret prompt via rofi, shared by the VPN and Wi-Fi connect flows.
// rofi -password reads no entries from stdin; sh -c gives us an empty pipe
// so rofi doesn't block on a terminal-less invocation.
export async function promptPassword(prompt: string): Promise<string | null> {
  const safe = prompt.replace(/"/g, '\\"')
  try {
    const out = await execAsync([
      "sh",
      "-c",
      `printf '' | rofi -dmenu -password -p "${safe}" -lines 0`,
    ])
    const pass = out.replace(/\n$/, "")
    return pass.length ? pass : null
  } catch {
    return null
  }
}
