#!/bin/bash
#
# Reset the traffic counter shown by waybar (custom/downloaded).
# Usage: reset_network_total.sh [interface]   (default: interface of the default route)

IFACE=$1
if [[ -z $IFACE ]]; then
	while read -r ifc dest _; do
		[[ $dest == 00000000 ]] && IFACE=$ifc && break
	done </proc/net/route
fi
[[ -n $IFACE ]] || exit 1

cat "/sys/class/net/$IFACE/statistics/rx_bytes" >/tmp/network_rx_reset
cat "/sys/class/net/$IFACE/statistics/tx_bytes" >/tmp/network_tx_reset
pkill -x -RTMIN+8 waybar 2>/dev/null
