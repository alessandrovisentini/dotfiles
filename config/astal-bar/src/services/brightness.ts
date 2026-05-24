// Brightness has no Astal lib — poll brightnessctl and hide on no-backlight.
import { Variable } from "astal"
import { execAsync } from "astal/process"
import { sh } from "../utils/shell"

export const hasBacklight = Variable(false)

export const brightness = Variable(0).poll(2000, async () => {
  try {
    const [cur, max] = await Promise.all([
      execAsync(["brightnessctl", "get"]),
      execAsync(["brightnessctl", "max"]),
    ])
    const c = Number(cur)
    const m = Number(max)
    hasBacklight.set(m > 0)
    return m > 0 ? Math.round((c / m) * 100) : 0
  } catch {
    return 0
  }
})

export function setBrightness(value: number) {
  const v = Math.max(1, Math.min(100, Math.round(value)))
  brightness.set(v)
  sh(["brightnessctl", "set", `${v}%`])
}
