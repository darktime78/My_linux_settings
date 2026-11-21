#!/bin/bash
#
# Called by swayidle after a long idle period: suspend the machine, but only
# when it is running on battery. On AC power (or on a desktop) do nothing.

shopt -s nullglob

for bat in /sys/class/power_supply/BAT*; do
	read -r status <"$bat/status" || continue
	if [[ $status == Discharging ]]; then
		exec systemctl suspend
	fi
done

exit 0
