#!/bin/bash
#
# Start waybar (both bars) and restart it if it crashes or is killed.
# Use ~/.config/sway/bar.sh to show / hide / restart it.
#
# Quick repeated crashes (e.g. a typo in waybar.conf) back off and finally
# give up with a notification, instead of spinning in a busy loop that
# burns CPU and battery.

CONFIG="$HOME/.config/sway/waybar.conf"
STYLE="$HOME/.config/sway/style.css"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}"
LOG="$RUNDIR/waybar.log"
HIDDEN="$RUNDIR/waybar.hidden"

# Only one wrapper per session
exec 9>"$RUNDIR/waybar-wrapper.lock"
flock -n 9 || exit 0

: >"$LOG"
fails=0

while :; do
	# Stop when the sway session is gone or the bar was hidden
	[[ -n $SWAYSOCK && -S $SWAYSOCK ]] || break
	[[ -e $HIDDEN ]] && break

	started=$SECONDS
	echo "$(date '+%F %T') starting waybar" >>"$LOG"
	waybar -c "$CONFIG" -s "$STYLE" "$@" >>"$LOG" 2>&1 9>&-
	code=$?
	echo "$(date '+%F %T') waybar exited with code $code" >>"$LOG"

	[[ -e $HIDDEN ]] && break

	# Killed by a signal (restart / hide) is not a crash
	if (( code < 128 && SECONDS - started < 10 )); then
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
