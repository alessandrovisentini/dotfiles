import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

export default class MoveWithoutFollowExtension extends Extension {
    enable() {
        this._grabs = [];
        for (let i = 1; i <= 9; i++) {
            const accel = `<Super><Shift>${i}`;
            const action = global.display.grab_accelerator(accel, Meta.KeyBindingFlags.NONE);
            if (action === Meta.KeyBindingAction.NONE)
                continue;
            const name = Meta.external_binding_name_for_action(action);
            Main.wm.allowKeybinding(name, Shell.ActionMode.NORMAL | Shell.ActionMode.OVERVIEW);
            this._grabs.push({action, name, idx: i - 1});
        }
        this._signalId = global.display.connect('accelerator-activated', (_display, action) => {
            const grab = this._grabs.find(g => g.action === action);
            if (!grab)
                return;
            const win = global.display.focus_window;
            if (!win)
                return;
            const wsManager = global.workspace_manager;
            if (grab.idx >= wsManager.get_n_workspaces())
                return;
            win.change_workspace_by_index(grab.idx, false);
        });
    }

    disable() {
        if (this._signalId) {
            global.display.disconnect(this._signalId);
            this._signalId = null;
        }
        for (const g of this._grabs)
            global.display.ungrab_accelerator(g.action);
        this._grabs = [];
    }
}
