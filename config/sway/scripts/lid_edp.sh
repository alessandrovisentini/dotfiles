#!/bin/sh
# Blank the internal panel on lid close, but only when docked — i.e. more than
# one output is connected. Undocked there's just eDP-1 and closing the lid
# suspends instead; disabling eDP-1 here would leave the desktop as its last
# frame and flash it back on resume, so we let swaylock (before-sleep) cover it.
[ "$(swaymsg -t get_outputs | grep -c '"name":')" -gt 1 ] && swaymsg 'output eDP-1 disable'
