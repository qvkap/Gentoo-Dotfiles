#!/bin/sh

case "$1" in
    vol+)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
        pkill -USR1 -f /home/rorka/.config/sway/status.sh
        ;;
    vol-)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        pkill -USR1 -f /home/rorka/.config/sway/status.sh
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        pkill -USR1 -f /home/rorka/.config/sway/status.sh
        ;;
esac

vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
if echo "$vol" | grep -q "MUTED"; then
    notify-send -h string:x-canonical-private-synchronous:vol "Звук" "Без звука"
else
    val=$(echo "$vol" | awk '{print int($2*100)}')
    notify-send -h int:value:"$val" -h string:x-canonical-private-synchronous:vol "Громкость" "$val%"
fi
