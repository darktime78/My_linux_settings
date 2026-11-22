#!/bin/bash
#
# On/off button for a service on waybar (custom/fim, custom/router).
# Commands for each service are in ~/.config/sway/services.conf
#
#   waybar_service.sh NAME          print the state as JSON for waybar
#   waybar_service.sh NAME toggle   start it if stopped, stop it if running

CONF="$HOME/.config/sway/services.conf"
NAME=$1
SIGNAL=9 # "signal" of the custom modules in waybar.conf

# shellcheck source=/dev/null
source "$CONF" 2>/dev/null || {
	echo '{"text": "?", "alt": "off", "class": "off", "tooltip": "missing ~/.config/sway/services.conf"}'
	exit 0
}

label=${LABEL[$NAME]:-$NAME}

if [[ -z ${CHECK[$NAME]} ]]; then
	printf '{"text": "%s", "alt": "off", "class": "off", "tooltip": "%s is not set up in services.conf"}\n' "$label" "$NAME"
	exit 0
fi

running() { bash -c "${CHECK[$NAME]}" >/dev/null 2>&1; }

if [[ $2 == toggle ]]; then
	if running; then
		bash -c "${STOP[$NAME]}" >/dev/null 2>&1 || notify-send -u critical "$label" "Could not stop"
		notify-send -t 2000 "$label" "Stopped"
	else
		bash -c "${START[$NAME]}" >/dev/null 2>&1 || notify-send -u critical "$label" "Could not start"
		notify-send -t 2000 "$label" "Started"
	fi
	pkill -x -RTMIN+$SIGNAL waybar # refresh the buttons now
	exit 0
fi

if running; then
	printf '{"text": "%s", "alt": "on", "class": "on", "tooltip": "%s is running\\nClick: stop"}\n' "$label" "$label"
else
	printf '{"text": "%s", "alt": "off", "class": "off", "tooltip": "%s is stopped\\nClick: start"}\n' "$label" "$label"
fi
