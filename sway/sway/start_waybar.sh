#!/bin/bash
#
# Start waybar and restart it if it crashes or is killed
# ("pkill -x waybar" = restart the bar with the new config).
#
# Quick repeated failures (e.g. a typo in waybar.conf) back off and finally
# give up with a notification, instead of spinning in a busy loop that
# burns CPU and battery.

CONFIG="$HOME/.config/sway/waybar.conf"
STYLE="$HOME/.config/sway/style.css"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$RUNDIR/waybar.log"

# Only one wrapper per session
exec 9>"$RUNDIR/waybar-wrapper.lock"
flock -n 9 || exit 0

: >"$LOG"
fails=0

while :; do
	# Stop when the sway session is gone
	[[ -n $SWAYSOCK && -S $SWAYSOCK ]] || break

	started=$SECONDS
	echo "$(date '+%F %T') starting waybar" >>"$LOG"
	waybar -c "$CONFIG" -s "$STYLE" "$@" >>"$LOG" 2>&1 9>&-
	code=$?
	echo "$(date '+%F %T') waybar exited with code $code" >>"$LOG"

	if (( SECONDS - started < 10 )); then
		(( fails++ ))
	else
		fails=0
	fi

	if (( fails >= 5 )); then
		notify-send -u critical "Waybar keeps crashing" "See $LOG"
		break
	fi

	sleep $(( fails * 2 + 1 ))
done
