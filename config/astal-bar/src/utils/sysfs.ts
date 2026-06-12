import GLib from "gi://GLib"

// Read a small text file (sysfs/procfs); null on any error.
export function readFile(path: string): string | null {
  try {
    const [ok, bytes] = GLib.file_get_contents(path)
    return ok && bytes ? new TextDecoder().decode(bytes) : null
  } catch {
    return null
  }
}
