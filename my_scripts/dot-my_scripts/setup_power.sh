#!/bin/bash
#
# Battery / power saving setup for a laptop. Run as root:
#   # ./setup_power.sh
#
# Every step asks before changing anything.

set -u

RED="\033[0;31m"
GRN="\033[0;32m"
BLU="\033[0;36m"
NC="\033[0m"

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}Run this script as root${NC}"
	exit 1
fi

ask() {
	local answer
	echo -ne "${BLU}$1 [y/N]: ${NC}"
	read -r answer
	[[ $answer == [yY] ]]
}

ok() { echo -e "[$GRN  OK  $NC]    $1"; }

## 1. power-profiles-daemon (waybar shows it, click on the icon to switch)
echo
echo "power-profiles-daemon switches CPU/platform power profiles"
echo "(power-saver / balanced / performance). Waybar has a button for it."
if systemctl is-enabled -q tlp.service 2>/dev/null; then
	echo -e "${RED}TLP is enabled. TLP and power-profiles-daemon conflict, keep only one.${NC}"
	echo "Skipping power-profiles-daemon."
elif ask "Install and enable power-profiles-daemon?"; then
	pacman -S --needed --noconfirm power-profiles-daemon
	systemctl enable --now power-profiles-daemon.service
	ok "power-profiles-daemon"
fi

## 2. Sound card power saving (Intel HDA)
echo
echo "Let the sound card sleep after 1 s of silence (saves ~0.5 W)."
echo "Some cards make a small 'pop' when waking up; delete the file to undo."
CONF=/etc/modprobe.d/audio_powersave.conf
if [[ -e $CONF ]]; then
	ok "$CONF already exists"
elif ask "Enable snd_hda_intel power_save?"; then
	echo "options snd_hda_intel power_save=1" >"$CONF"
	ok "$CONF (active after reboot)"
fi

## 3. Bluetooth off by default
echo
BT_CONF=/etc/bluetooth/main.conf
if [[ -f $BT_CONF ]]; then
	echo "Do not power on the bluetooth adapter automatically on boot."
	echo "You can still enable it any time: bluetoothctl power on"
	if ask "Disable bluetooth AutoEnable?"; then
		if grep -q '^#\?AutoEnable' "$BT_CONF"; then
			sed -i -e 's/^#\?AutoEnable=.*/AutoEnable=false/' "$BT_CONF"
		else
			sed -i -e '/^\[Policy\]/a AutoEnable=false' "$BT_CONF"
		fi
		ok "$BT_CONF"
	fi
fi

## 4. Less frequent disk writeback
echo
echo "Write dirty data to disk every 15 s instead of every 5 s."
SYSCTL=/etc/sysctl.d/90-laptop-writeback.conf
if [[ -e $SYSCTL ]]; then
	ok "$SYSCTL already exists"
elif ask "Enable lazier writeback?"; then
	echo "vm.dirty_writeback_centisecs = 1500" >"$SYSCTL"
	sysctl -q --system
	ok "$SYSCTL"
fi

echo
echo "More tips: https://wiki.archlinux.org/title/Power_management"
echo "Measure power usage with: powertop  (pacman -S powertop)"
