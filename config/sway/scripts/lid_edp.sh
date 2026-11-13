#!/bin/sh
# Only when docked (more than one output). Undocked, closing the lid suspends and swaylock covers
# the screen; disabling eDP-1 would flash the last frame back on resume.
[ "$(swaymsg -t get_outputs | grep -c '"name":')" -gt 1 ] && swaymsg 'output eDP-1 disable'
