import type { Variable } from "astal"
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
  // Derived Variables created for this row; dropped when the row is
  // destroyed so list rebuilds don't leak their dep subscriptions.
  owns?: Array<Variable<any>>
  onClicked?: () => void
}

export interface MenuWindowProps {
  name: string
  child: JSX.Element
  side?: "left" | "right"
  klass?: string
}
