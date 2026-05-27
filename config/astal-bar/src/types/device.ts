// Per-device configuration consumed by bar services that need
// hardware-aware behaviour.
export interface DeviceConfig {
  // Match against AstalWp's `endpoint.device.description` to classify
  // integrated (built-in) audio endpoints, separating them from HDMI,
  // USB, and Bluetooth devices for the naming/ordering pass.
  integratedAudioPattern: RegExp
}
