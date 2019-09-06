#!/bin/bash
URL="http://www.tagesschau.de/export/podcast/hi/tagesschau-in-100-sekunden/"
M3U="/var/lib/mpd/playlists/wakeup.m3u"
URL2File=$(wget -q -O - $URL | sed -n 's/.*enclosure.*url="\([^"]*\)" .*/\1/p')
cat >"$M3U" <<EOF
#EXTM3U
#EXTINF:-1,Meeresrauschen
/var/lib/mpd/music/Meeresbrandung-auf-Felsen.mp3
#EXTINF:-1,Tagesschau-100sec
$URL2File
#EXTINF:-1,Gong96.3
#EXTVLCOPT:network-caching=1000
http://mp3.radiogong963.c.nmdn.net/ps-radiogong963/livestream.mp3?
#EXTINF:-1,Alarm-Clock
/var/lib/mpd/music/alarm_clock_nice.mp3
EOF

