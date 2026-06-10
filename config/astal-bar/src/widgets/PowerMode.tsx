import { Variable, bind } from "astal"
import { PERF_ICONS } from "../const/icons"
import { MENU } from "../const/menu"
import { toggleMenu } from "../services/menu"
import { activeProfile, perfMode } from "../services/powerProfile"
import { tap } from "../utils/gtk"

const NAME = {
  "power-saver": "Power Saver",
  balanced: "Balanced",
  performance: "Performance",
} as const

export function PowerMode() {
  // In auto the glyph (and its color) reflect the auto-selected profile.
  const icon = bind(activeProfile).as((p) => PERF_ICONS[p])
  const cls = bind(activeProfile).as((p) => `perf-icon perf-${p}`)
  const tip = Variable.derive(
    [bind(perfMode), bind(activeProfile)],
    (mode, p) => (mode === "auto" ? `Automatic · ${NAME[p]}` : NAME[p]),
  )
  return (
    <button
      className="bar-button"
      tooltipText={bind(tip)}
      onClicked={tap(() => toggleMenu(MENU.perf))}
    >
      <label className={cls} label={icon} />
    </button>
  )
}
