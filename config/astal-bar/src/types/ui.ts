import type { Reactive } from "../utils/reactive"

export interface RowProps {
  icon: Reactive<string>
  name: Reactive<string>
  // Extra class on the row root (e.g. to tint the icon).
  klass?: string
  status?: Reactive<string>
  active?: Reactive<boolean>
  // When set, the icon glyph is replaced by a spinner while it reads true.
  busy?: Reactive<boolean>
  visible?: Reactive<boolean>
  action?: JSX.Element
  onClicked?: () => void
}

export interface MenuWindowProps {
  name: string
  child: JSX.Element
  side?: "left" | "right"
  klass?: string
}
