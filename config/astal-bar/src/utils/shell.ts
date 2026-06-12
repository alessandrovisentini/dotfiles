import { execAsync } from "astal/process"

export const sh = (cmd: string[]) => execAsync(cmd).catch(() => {})

export const pct = (v: number) => `${Math.round(v * 100)}%`

// "2h 5m" / "45m"; empty when the estimate is unknown (0).
export function dur(secs: number): string {
  if (secs <= 0) return ""
  const h = Math.floor(secs / 3600)
  const m = Math.round((secs % 3600) / 60)
  return h > 0 ? `${h}h ${m}m` : `${m}m`
}
