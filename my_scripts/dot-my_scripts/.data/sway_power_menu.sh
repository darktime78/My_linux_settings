#!/bin/bash
#
# Power menu: lock / suspend / log out / reboot / power off.
# Log out, reboot and power off ask for confirmation.

LOCK=~/.my_scripts/.data/sway_start_lockscreen.sh

lock=$'  Lock'
suspend=$'  Suspend'
logout=$'  Log out'
reboot=$'  Reboot'
poweroff=$'  Power off'

confirm() {
	[[ $(printf 'No\nYes\n' | rofi -dmenu -i -no-custom -p "$1?") == Yes ]]
}

choice=$(printf '%s\n' "$lock" "$suspend" "$logout" "$reboot" "$poweroff" |
	rofi -dmenu -i -no-custom -p "Power")

case $choice in
"$lock") exec "$LOCK" ;;
"$suspend") exec systemctl suspend ;; # swayidle locks before sleep
"$logout") confirm "Log out" && exec swaymsg exit ;;
"$reboot") confirm "Reboot" && exec systemctl reboot ;;
"$poweroff") confirm "Power off" && exec systemctl poweroff ;;
esac
