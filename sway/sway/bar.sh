#!/bin/bash
#
# Bar control for sway key bindings.
#
#   bar.sh start    start the bars (used at login)
#   bar.sh toggle   hide / show both bars        ($mod+m)
#   bar.sh restart  restart, re-reads waybar.conf ($mod+Shift+m)
#
# Hiding really stops waybar (it uses no CPU while hidden). This works even
# when waybar is not running at all, unlike the SIGUSR1 signal.

RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
HIDDEN="$RUNDIR/waybar.hidden"
WRAPPER="$HOME/.config/sway/start_waybar.sh"

running() { pgrep -x waybar >/dev/null; }

start() {
	rm -f "$HIDDEN"
	# start_waybar.sh allows only one copy of itself, so this is safe
	setsid -f "$WRAPPER" >/dev/null 2>&1
}

case $1 in
start)
	start
	;;
toggle)
	if running; then
		touch "$HIDDEN" # tells start_waybar.sh not to restart it
		pkill -x waybar
	else
		start
	fi
	;;
restart)
	rm -f "$HIDDEN"
	if running; then
		pkill -x waybar # start_waybar.sh starts it again
	else
		start
	fi
	;;
*)
	echo "usage: $0 start|toggle|restart" >&2
	exit 1
	;;
esac
