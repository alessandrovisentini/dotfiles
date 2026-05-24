export interface SwayWorkspace {
  num: number
  name: string
  focused: boolean
  visible: boolean
  urgent: boolean
  output: string
}

export interface SwayOutput {
  name: string
  active: boolean
  rect: { x: number; y: number; width: number; height: number }
}
