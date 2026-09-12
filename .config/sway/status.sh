#!/bin/sh
prev_total=0
prev_active=0

update() {
    vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    if echo "$vol_raw" | grep -q "MUTED"; then
        audio_str="<span color='#f38ba8'>󰝟 MUTED</span>"
    else
        vol_pct=$(echo "$vol_raw" | awk '{print int($2 * 100)}')
        [ -z "$vol_pct" ] && vol_pct="0"
        audio_str="<span color='#a6e3a1'>󰕾 ${vol_pct}%</span>"
    fi

    read -r _ u n s i _ < /proc/stat
    total=$((u + n + s + i))
    active=$((u + n + s))
    if [ "$prev_total" -gt 0 ] && [ "$total" -gt "$prev_total" ]; then
        cpu_usage=$(( 100 * (active - prev_active) / (total - prev_total) ))
    else
        cpu_usage=0
    fi
    prev_total=$total
    prev_active=$active
    cpu_str="<span color='#fab387'>CPU ${cpu_usage}%</span>"

    ram_usage=$(free -m 2>/dev/null | awk '/Mem:/ {printf "%d%%", ($3/$2)*100}')
    ram_str="<span color='#cba6f7'>RAM ${ram_usage}</span>"

    date_str="<span color='#89b4fa'>$(date +'%d %b %H:%M:%S')</span>"

    echo "${cpu_str}  │  ${ram_str}  │  ${audio_str}  │  ${date_str}"
}

trap 'update' USR1

while true; do
    update
    sleep 0.4 &
    wait $!
done
