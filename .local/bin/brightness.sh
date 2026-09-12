#!/bin/sh

device=/sys/class/backlight/intel_backlight

step_pct=5
max=$(( $(cat "$device/max_brightness") ))
cur=$(( $(cat "$device/brightness") ))
step=$(( max * step_pct / 100 ))
[ "$step" -lt 1 ] && step=1

case "$1" in
    up)   new=$(( cur + step )) ;;
    down) new=$(( cur - step )) ;;
    *) echo "usage: brightness.sh up|down" >&2; exit 1 ;;
esac

[ "$new" -gt "$max" ] && new=$max
[ "$new" -lt 0 ] && new=0

if [ "$new" != "$cur" ]; then
    printf '%s' "$new" > "$device/brightness"
fi

pct=$(( new * 100 / max ))
notify-send -h int:value:"$pct" -h string:x-canonical-private-synchronous:brightness "Brightness" "$pct%"
