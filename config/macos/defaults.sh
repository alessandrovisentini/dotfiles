#!/usr/bin/env bash
# Some changes require logout or restart to take effect.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Applying macOS defaults..."

# Keyboard

defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# Caps Lock → Escape is set manually in System Settings > Keyboard
# > Keyboard Shortcuts > Modifier Keys. Clean up the legacy LaunchAgent
# in case an earlier hidutil-based remap is still around.
LEGACY_CAPSLOCK_AGENT="$HOME/Library/LaunchAgents/com.user.capslock-to-esc.plist"
if [[ -f "$LEGACY_CAPSLOCK_AGENT" ]]; then
    launchctl unload "$LEGACY_CAPSLOCK_AGENT" 2>/dev/null || true
    rm -f "$LEGACY_CAPSLOCK_AGENT"
fi

# Text input

defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Menu bar

defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Dock

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock tilesize -int 48
defaults write com.apple.dock persistent-apps -array

# Finder

defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Mission Control

defaults write com.apple.dock mru-spaces -bool false
# Instant cross-fade instead of horizontal slide.
defaults write com.apple.universalaccess reduceMotion -bool true

# Option+<n> → Desktop n
# Symbolic hotkey IDs: 118=Desktop1 .. 127=Desktop10. Parameters: (ASCII, keycode, modifier=524288).

defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 118 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>49</integer><integer>18</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 119 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>50</integer><integer>19</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 120 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>51</integer><integer>20</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 121 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 122 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>53</integer><integer>23</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 123 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>54</integer><integer>22</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 124 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>55</integer><integer>26</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 125 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>56</integer><integer>28</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 126 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>57</integer><integer>25</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 127 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>48</integer><integer>29</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Spotlight on Option+D; disable the Finder search shortcut to avoid conflicts.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>100</integer><integer>2</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>49</integer><integer>1572864</integer></array><key>type</key><string>standard</string></dict></dict>"

# Amethyst

AMETHYST_YAML_SRC="$SCRIPT_DIR/.amethyst.yml"
AMETHYST_YAML_DST="$HOME/.amethyst.yml"
if [[ -f "$AMETHYST_YAML_SRC" ]]; then
    echo "Linking Amethyst YAML config..."
    if [[ -L "$AMETHYST_YAML_DST" && "$(readlink "$AMETHYST_YAML_DST")" == "$AMETHYST_YAML_SRC" ]]; then
        :
    else
        if [[ -e "$AMETHYST_YAML_DST" || -L "$AMETHYST_YAML_DST" ]]; then
            mv "$AMETHYST_YAML_DST" "${AMETHYST_YAML_DST}.backup.$(date +%Y%m%d%H%M%S)"
        fi
        ln -s "$AMETHYST_YAML_SRC" "$AMETHYST_YAML_DST"
    fi
    # Clear stale prefs that would override the YAML, then restart.
    defaults delete com.amethyst.Amethyst 2>/dev/null || true
    killall cfprefsd 2>/dev/null || true
    killall Amethyst 2>/dev/null || true
fi

# Sketchybar

if command -v brew &>/dev/null && brew list sketchybar &>/dev/null; then
    echo "Starting sketchybar service..."
    brew services start sketchybar &>/dev/null || true
    brew services restart sketchybar &>/dev/null || true
fi

echo "Done! Some changes require logout or restart to take effect."
echo ""
echo "Restarting affected services..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "Services restarted."
