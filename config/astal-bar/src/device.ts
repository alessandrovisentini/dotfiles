// Picks the active device profile by exact-matching /sys/class/dmi/id/product_version.
// To add a new device: drop devices/<name>.ts and add an entry below.
import type { DeviceConfig } from "./types/device"
import { DEVICE as X12 } from "./devices/x12"
import { DEVICE as P14S } from "./devices/p14s"
import { readFile } from "./utils/sysfs"

const PROFILES: Record<string, DeviceConfig> = {
  "ThinkPad X12 Detachable Gen 1": X12,
  "ThinkPad P14s Gen 4": P14S,
}

const productVersion = (readFile("/sys/class/dmi/id/product_version") ?? "").trim()
export const DEVICE = PROFILES[productVersion] ?? P14S
