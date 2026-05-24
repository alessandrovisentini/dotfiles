import { execAsync } from "astal/process"

export const sh = (cmd: string[]) => execAsync(cmd).catch(() => {})

export const pct = (v: number) => `${Math.round(v * 100)}%`
