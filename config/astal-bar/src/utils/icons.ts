import {
  BATTERY_CHARGING,
  BATTERY_RAMP,
  VOLUME_RAMP,
  WIFI_RAMP,
} from "../const/icons"

export function wifiIcon(strength: number): string {
  if (strength >= 80) return WIFI_RAMP.full
  if (strength >= 55) return WIFI_RAMP.high
  if (strength >= 30) return WIFI_RAMP.medium
  if (strength >= 5) return WIFI_RAMP.low
  return WIFI_RAMP.off
}

export function volumeIcon(vol: number, mute: boolean): string {
  if (mute) return VOLUME_RAMP.mute
  if (vol <= 0.0) return VOLUME_RAMP.silent
  if (vol < 0.5) return VOLUME_RAMP.low
  return VOLUME_RAMP.full
}

export function batteryIcon(p: number, charging: boolean): string {
  if (charging) return BATTERY_CHARGING
  const i = Math.min(9, Math.max(0, Math.floor(p * 10)))
  return BATTERY_RAMP[i]
}
