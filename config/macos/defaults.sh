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
# Apply changes
# =============================================================================

echo "Done! Some changes require logout or restart to take effect."
echo ""
echo "Restarting affected services..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
echo "Services restarted."
