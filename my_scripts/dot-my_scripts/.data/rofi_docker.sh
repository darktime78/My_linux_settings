#!/bin/bash
#
# rofi "Docker" mode: lists every app from ~/.config/docker/dockerfunc.
#   stopped app  -> Enter starts it
#   running app  -> Enter asks "Stop <app>?"
#
# Open it with $mod+c (rofi_docker_menu.sh).

DATA="$HOME/.my_scripts/.data"
for f in ~/.config/docker/dockerfunc ~/.config/docker/dockerfunc_extra; do
	# shellcheck source=/dev/null
	[[ -f $f ]] && source "$f"
done

icon_for() {
	case $1 in
	firefox* | waterfox) echo firefox ;;
	chromium*) echo chromium ;;
	nvimcpp | nvimide) echo nvim ;;
	claude) echo web-browser ;;
	steam) echo steam ;;
	telegram) echo telegram ;;
	discord) echo discord ;;
	intellij) echo idea ;;
	vscode) echo visual-studio-code ;;
	mpd) echo multimedia-audio-player ;;
	postgres) echo office-database ;;
	nginx | json-server) echo network-server ;;
	*) echo utilities-terminal ;;
	esac
}

# Something was selected
if [[ -n $ROFI_INFO ]]; then
	action=${ROFI_INFO%%:*}
	name=${ROFI_INFO#*:}
	case $action in
	start)
		setsid -f "$DATA/docker_app.sh" "$name" >/dev/null 2>&1
		exit 0
		;;
	ask)
		printf '\0prompt\x1fStop %s?\n' "$name"
		printf 'Stop %s\0info\x1fstop:%s\x1ficon\x1fprocess-stop\n' "$name" "$name"
		printf 'Back\0info\x1fback:\x1ficon\x1fgo-previous\n'
		exit 0
		;;
	stop)
		setsid -f sh -c "docker stop '$name' >/dev/null 2>&1 && notify-send -t 2500 '$name' 'Stopped'" \
			>/dev/null 2>&1
		exit 0
		;;
	esac
fi

# Main list: running apps first
running=" $(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ') "
printf '\0prompt\x1fDocker\n'
printf '\0markup-rows\x1ftrue\n'

mapfile -t apps < <(declare -F | awk '{print $3}' | grep -vx 'del_stopped')
for f in "${apps[@]}"; do
	[[ $running == *" $f "* ]] &&
		printf '%s  <span foreground="#8bc34a">● running</span>\0info\x1fask:%s\x1ficon\x1f%s\n' \
			"$f" "$f" "$(icon_for "$f")"
done
for f in "${apps[@]}"; do
	[[ $running == *" $f "* ]] ||
		printf '%s\0info\x1fstart:%s\x1ficon\x1f%s\n' "$f" "$f" "$(icon_for "$f")"
done
