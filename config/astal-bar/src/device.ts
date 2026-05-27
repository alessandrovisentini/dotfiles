// Picks the active device profile by exact-matching /sys/class/dmi/id/product_version.
// To add a new device: drop devices/<name>.ts and add an entry below.
import GLib from "gi://GLib"
import type { DeviceConfig } from "./types/device"
import { DEVICE as X12 } from "./devices/x12"
import { DEVICE as P14S } from "./devices/p14s"

const PROFILES: Record<string, DeviceConfig> = {
  "ThinkPad X12 Detachable Gen 1": X12,
  "ThinkPad P14s Gen 4": P14S,
}

function readSysfs(path: string): string {
  try {
    const [ok, bytes] = GLib.file_get_contents(path)
    if (!ok || !bytes) return ""
    return new TextDecoder().decode(bytes).trim()
  } catch {
    return ""
  }
}

const productVersion = readSysfs("/sys/class/dmi/id/product_version")
export const DEVICE = PROFILES[productVersion] ?? P14S
