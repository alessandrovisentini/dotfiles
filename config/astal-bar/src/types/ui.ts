export interface RowProps {
  active?: boolean
  icon: string
  name: any
  status?: string
  onClicked?: () => void
  action?: any
  visible?: any
}

export interface MenuWindowProps {
  name: string
  child: any
  side?: "left" | "right"
  klass?: string
}
