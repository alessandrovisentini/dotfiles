import { tap } from "../utils/gtk"

export function HeaderButton(icon: string, onClicked: () => void, tooltip?: string) {
  return (
    <button className="icon-btn" onClicked={tap(onClicked)} tooltipText={tooltip ?? ""}>
      <label label={icon} />
    </button>
  )
}
