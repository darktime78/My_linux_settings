#!/bin/bash

set -u

RED="\033[0;31m"
GRN="\033[0;32m"
BLU="\033[0;36m"
NC="\033[0m"

LIST=""

check_bin() {
	if command -v "$1" >/dev/null 2>&1; then
		echo -e "[$GRN  OK  $NC]    $1"
		return
	fi
	local pkg=$2
	[[ $pkg == '*' ]] && pkg=$1
	echo -e "[$RED FAIL $NC]    Can't find '$1' bin, try install '${BLU}${pkg}${NC}' packet: $3"
	LIST+=" $pkg"
}

check_pkt() {
	if pacman -Qq "$1" >/dev/null 2>&1; then
		echo -e "[$GRN  OK  $NC]    $1"
	else
		echo -e "[$RED FAIL $NC]    Can't find '$1' packet, try install '${BLU}$1${NC}' packet: $2"
		LIST+=" $1"
	fi
}

echo "Wayland:"
check_bin "sway"     "*"            "Sway tiling window manager"
check_bin "swaybg"   "*"            "Setup wallpapers"
check_bin "swayidle" "*"            "Dim / lock / screen off / suspend when idle"
check_bin "swaylock" "*"            "Lockscreen"
check_bin "mako"     "*"            "Notification server"
check_bin "grim"     "*"            "Screenshots"
check_bin "slurp"    "*"            "Select the part of screen"
check_bin "wl-copy"  "wl-clipboard" "Copy text to clipboard"
check_bin "waybar"   "*"            "Top bar"
check_bin "rofi"     "*"            "Application launcher and power menu"
check_pkt "xdg-desktop-portal-wlr"  "Screen sharing in browsers / Telegram / Discord"
check_pkt "xdg-desktop-portal-gtk"  "File open dialogs for sandboxed apps"

echo "Fonts:"
check_pkt "powerline-fonts-git"     "Terminal and powerline font"
check_pkt "cantarell-fonts"         "Bar and window title font"
check_pkt "ttf-hack"                "Alacritty font"

echo "Sound:"
echo "  (PipeWire replaces PulseAudio. If pulseaudio is installed, pacman will"
echo "   offer to replace it with pipewire-pulse - answer yes.)"
check_pkt "pipewire"                        "Sound server"
check_pkt "pipewire-pulse"                  "PulseAudio compatibility (waybar, pamixer, pavucontrol)"
check_pkt "wireplumber"                     "PipeWire session manager"
check_bin "pavucontrol"        "*"          "GUI mixer"
check_bin "pamixer"            "*"          "Volume keys"
check_bin "alsamixer"          "alsa-utils" "Console volume control"
check_bin "mpc"                "*"          "Media keys for mpd"

echo "Power:"
check_pkt "power-profiles-daemon"   "Power profiles, button in waybar (see setup_power.sh)"
check_bin "brightnessctl" "*"       "Display backlight, dim on idle"

echo "Legacy:"
check_bin "Xwayland" "xorg-xwayland" "Start X server"

echo "Tools:"
check_bin "jq"           "*"         "Command-line JSON parser (screenshots)"
check_pkt "alacritty"                "Terminal"
check_bin "notify-send"  "libnotify" "Command-line notify utility"
check_bin "flock"        "util-linux" "Single instance for bar/battery scripts"

if [[ $LIST ]]; then
	echo "Use:"
	echo "yay -S$LIST"
	echo

	echo -n "Do you want to install the required applications? [y/N]: "
	CONFIRM=""
	read CONFIRM
	if [[ $CONFIRM == 'y' || $CONFIRM == 'Y' ]]; then
		yay -S $LIST
	fi
fi
