#!/bin/sh
prev_total=0
prev_active=0
prev_uptime_cs=0
prev_rc6=0

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

    # GPU Usage (via Intel RC6 residency)
    if [ -f /sys/class/drm/card0/gt/gt0/rc6_residency_ms ]; then
        read -r cur_rc6 < /sys/class/drm/card0/gt/gt0/rc6_residency_ms
        read -r up_s _ < /proc/uptime
        cur_uptime_cs=$(echo "$up_s" | tr -d .)
        if [ "$prev_uptime_cs" -gt 0 ]; then
            d_time=$(( (cur_uptime_cs - prev_uptime_cs) * 10 ))
            d_rc6=$(( cur_rc6 - prev_rc6 ))
            if [ "$d_time" -gt 0 ]; then
                idle=$(( (d_rc6 * 100) / d_time ))
                [ "$idle" -gt 100 ] && idle=100
                [ "$idle" -lt 0 ] && idle=0
                gpu_usage=$(( 100 - idle ))
            else
                gpu_usage=0
            fi
        else
            gpu_usage=0
        fi
        prev_rc6=$cur_rc6
        prev_uptime_cs=$cur_uptime_cs
        gpu_str="<span color='#94e2d5'>GPU ${gpu_usage}%</span>"
    else
        gpu_str=""
    fi

    ram_usage=$(free -m 2>/dev/null | awk '/Mem:/ {printf "%d%%", ($3/$2)*100}')
    ram_str="<span color='#cba6f7'>RAM ${ram_usage}</span>"

    date_str="<span color='#89b4fa'>$(date +'%d %b %H:%M:%S')</span>"

    if [ -n "$gpu_str" ]; then
        echo "${cpu_str}  │  ${gpu_str}  │  ${ram_str}  │  ${audio_str}  │  ${date_str}"
    else
        echo "${cpu_str}  │  ${ram_str}  │  ${audio_str}  │  ${date_str}"
    fi
}

trap 'update' USR1

while true; do
    update
    sleep 0.4 &
    wait $!
done
