import { Gdk } from "astal/gtk3"

// True if the default seat advertises wl_touch. Evaluated once at
// startup; touch hotplug while the bar is running is rare enough to
// not be worth a reactive binding.
export const hasTouch: boolean = (() => {
  try {
    const seat = Gdk.Display.get_default()?.get_default_seat()
    if (!seat) return false
    return (seat.get_capabilities() & Gdk.SeatCapabilities.TOUCH) !== 0
  } catch {
    return false
  }
})()
