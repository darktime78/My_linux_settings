#!/bin/bash
#
# Toggle "do not disturb" (hide all notifications) in mako.

if makoctl mode | grep -qx do-not-disturb; then
	makoctl mode -r do-not-disturb >/dev/null
	notify-send -t 2000 "Notifications" "Do not disturb: off"
else
	notify-send -t 1500 "Notifications" "Do not disturb: on"
	sleep 1.6
	makoctl mode -a do-not-disturb >/dev/null
fi
