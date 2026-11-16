#!/bin/sh
# DEBUG ONLY. If the InvizBox recovery stick (has root_uImage) is inserted,
# snapshot boot diagnostics onto it every 10 s for 10 min. Never touches root_uImage.
M=/tmp/bootlog-usb
mkdir -p $M
for i in $(seq 1 90); do [ -b /dev/sda1 ] && break; sleep 1; done
[ -b /dev/sda1 ] || exit 0
mount -t vfat -o noatime /dev/sda1 $M || exit 0
[ -f $M/root_uImage ] || { umount $M; exit 0; }
n=1; while [ -e $M/bootlog-$n ]; do n=$((n+1)); done
D=$M/bootlog-$n; mkdir -p $D
{ date; cat /proc/uptime; cat /etc/openwrt_release; } > $D/start.txt
for t in $(seq 0 10 600); do
	dmesg > $D/dmesg.txt 2>&1
	logread > $D/logread.txt 2>&1
	{ echo "== t=$t uptime $(cat /proc/uptime)"; iw dev; ubus call network.wireless status; ps w; ifconfig; free; ls /etc/uci-defaults; } > $D/state-$t.txt 2>&1
	sync
	sleep 10
done
sync; umount $M
