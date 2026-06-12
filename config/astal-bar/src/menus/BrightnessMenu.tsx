import { bind } from "astal"
import { Icon } from "../const/icons"
import { MENU } from "../const/menu"
import { brightness, setBrightness } from "../services/brightness"
import { Section } from "../ui/Section"
import { MenuWindow } from "./MenuWindow"

export function BrightnessMenu() {
  return MenuWindow({
    name: MENU.brightness,
    klass: "bright",
    child: (
      <box vertical>
        {Section(
          "Brightness",
          <box className="vol-row">
            <label className="dev-icon" label={Icon.brightness} />
            <slider
              hexpand
              min={1}
              max={100}
              step={1}
              value={bind(brightness)}
              // astal applies bound props before static ones, so the initial
              // value is clamped against the slider's default 0..1 range and
              // the knob sticks at the far left. setup runs after all props:
              // re-assert the real value once.
              setup={(self: any) => (self.value = brightness.get())}
              onDragged={({ value }: any) => setBrightness(value)}
            />
            <label label={bind(brightness).as((v) => `${v}%`)} />
          </box>,
        )}
      </box>
    ),
  })
}
