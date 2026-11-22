#!/bin/bash
#
# Lock the screen.
#
# Returns as soon as the screen is locked (swaylock -f), so it is safe to
# use from swayidle's "before-sleep" hook: the laptop suspends right away
# and is already locked when it wakes up.
#
# While locked: notifications are hidden (mako "do-not-disturb" mode) and
# the screen is powered off after 10 seconds without input.

# Already locked
pidof -q swaylock && exit 0

# Hide notifications on the lock screen (remember if DND was already on)
had_dnd=0
if makoctl mode 2>/dev/null | grep -qx do-not-disturb; then
	had_dnd=1
else
	makoctl mode -a do-not-disturb >/dev/null 2>&1
fi

restore_notifications() {
	(( had_dnd )) || makoctl mode -r do-not-disturb >/dev/null 2>&1
}

letterEnteredColor=d23c3dff
letterRemovedColor=d23c3dff
passwordCorrect=00000000
passwordIncorrect=d23c3dff
background=00000000
foreground=ffffffff

if [[ -f ~/.wallpapers/lockscreen.png ]]; then
	image=(-i ~/.wallpapers/lockscreen.png)
else
	image=(-c 1d2026)
fi

if ! swaylock -f "${image[@]}" \
	--inside-color=$background --ring-color=$foreground --line-uses-inside \
	--key-hl-color=$letterEnteredColor --bs-hl-color=$letterRemovedColor --separator-color=$background \
	--inside-ver-color=$passwordCorrect --inside-wrong-color=$passwordIncorrect \
	--ring-ver-color=$foreground --ring-wrong-color=$foreground \
	--indicator-radius=40 --indicator-thickness=4 \
	--text-ver-color=$foreground --font=Hack; then
	restore_notifications
	exit 1
fi

# Runs in the background until the user unlocks
(
	lock_pid=$(pidof -s swaylock)

	# Screen off after 10 s on the lock screen. This is a separate swayidle
	# instance, the main one from the sway config is left untouched.
	swayidle timeout 10 'swaymsg "output * power off"' \
		resume 'swaymsg "output * power on"' &
	idle_pid=$!

	[[ -n $lock_pid ]] && tail --pid="$lock_pid" -s 2 -f /dev/null

	kill "$idle_pid" 2>/dev/null
	swaymsg 'output * power on'
	restore_notifications
) >/dev/null 2>&1 &

exit 0
