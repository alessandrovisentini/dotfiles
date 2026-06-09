import { Binding, Variable, bind } from "astal"

// A prop value that may be static or reactive. Astal widgets accept either
// directly for most attributes; toBinding is only needed where we derive a
// value (className, icon/spinner swap).
export type Reactive<T> = T | Binding<T>

// Lift a static value, Variable or Binding into a Binding so callers can
// uniformly derive with `.as`. Variables lack `.as`, hence bind().
export function toBinding<T>(v: Reactive<T>): Binding<T> {
  if (v instanceof Variable) return bind(v)
  if (v && typeof (v as { as?: unknown }).as === "function") return v as Binding<T>
  return bind(Variable(v as T))
}
