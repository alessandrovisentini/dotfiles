#!/usr/bin/env bash

# macOS defaults configuration
# Run this script to apply keyboard and other system settings
# Some changes require logout/restart to take effect

set -e

echo "Applying macOS defaults..."

# =============================================================================
# Keyboard Settings
# =============================================================================

# Key repeat rate (lower = faster, default is 6)
defaults write NSGlobalDomain KeyRepeat -int 2

# Delay until key repeat (lower = shorter, default is 25)
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Disable press-and-hold for keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Use F1, F2, etc. as standard function keys
# (requires: System Settings > Keyboard > Keyboard Shortcuts > Function Keys)
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true

# =============================================================================
# Text Input / Autocorrect
# =============================================================================

# Disable automatic capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable smart dashes
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable automatic period substitution
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# =============================================================================
# Menu Bar
# =============================================================================

# Auto-hide menu bar
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# =============================================================================
# Dock
# =============================================================================

# Auto-hide dock
defaults write com.apple.dock autohide -bool true

# Remove dock auto-hide delay
defaults write com.apple.dock autohide-delay -float 0

# Dock icon size
defaults write com.apple.dock tilesize -int 48

# =============================================================================
# Finder
# =============================================================================

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# =============================================================================
# Mission Control / Spaces
# =============================================================================

# Disable automatic rearranging of Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# =============================================================================
# Keyboard Shortcuts - Switch to Desktop with Option+N
# =============================================================================
# Symbolic hotkey IDs: 118=Desktop1 ... 126=Desktop9, 127=Desktop10
# Parameters: (ASCII code, virtual keycode, modifier flags)
# Option modifier = 524288

# Option+1 → Desktop 1
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 118 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>49</integer><integer>18</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+2 → Desktop 2
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 119 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>50</integer><integer>19</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+3 → Desktop 3
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 120 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>51</integer><integer>20</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+4 → Desktop 4
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 121 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+5 → Desktop 5
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 122 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>53</integer><integer>23</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+6 → Desktop 6
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 123 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>54</integer><integer>22</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+7 → Desktop 7
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 124 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>55</integer><integer>26</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+8 → Desktop 8
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 125 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>56</integer><integer>28</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+9 → Desktop 9
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 126 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>57</integer><integer>25</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Option+0 → Desktop 10
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 127 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>48</integer><integer>29</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# =============================================================================
# Keyboard Shortcuts - Spotlight
# =============================================================================

# Option+D → Show Spotlight search (replaces default Cmd+Space)
# Symbolic hotkey ID 64 = Spotlight search
# D: ASCII 100, keycode 2, Option modifier 524288
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>100</integer><integer>2</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>"

# Disable Finder search window shortcut (Cmd+Option+Space) to avoid conflicts
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>49</integer><integer>1572864</integer></array><key>type</key><string>standard</string></dict></dict>"

# =============================================================================
# Apply changes
# =============================================================================

echo "Done! Some changes require logout or restart to take effect."
echo ""
echo "Restarting affected services..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "Services restarted."
