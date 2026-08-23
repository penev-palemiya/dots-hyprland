#!/usr/bin/env bash
set -u

CONFIG_FILE="${HOME}/.config/illogical-impulse/config.json"
RUNTIME_BASE="${XDG_RUNTIME_DIR:-/tmp}"
RUNTIME_DIR="${RUNTIME_BASE}/illogical-impulse"
STATE_FILE="${RUNTIME_DIR}/screen-recording.state"
LOCK_FILE="${RUNTIME_DIR}/screen-recording.lock"

mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR" 2>/dev/null || true

operation="toggle"
if [[ "${1:-}" == "start" || "${1:-}" == "stop" || "${1:-}" == "status" || "${1:-}" == "toggle" ]]; then
    operation="$1"
    shift
elif (($#)); then
    operation="start"
fi

read_state() {
    [[ -r "$STATE_FILE" ]] || return 1
    state_pid=""; state_pid_start=""; state_controller=""; state_started=""; state_mode=""; state_audio=""; state_output=""
    while IFS='=' read -r key value; do
        case "$key" in
            pid) state_pid="$value" ;;
            pid_start_ticks) state_pid_start="$value" ;;
            controller_pid) state_controller="$value" ;;
            started_at) state_started="$value" ;;
            mode) state_mode="$value" ;;
            system_audio) state_audio="$value" ;;
            output_path) state_output="$value" ;;
        esac
    done < "$STATE_FILE"
    [[ "$state_pid" =~ ^[0-9]+$ ]]
}

owned_pid() {
    local pid="$1"
    [[ "$pid" =~ ^[0-9]+$ && -r "/proc/$pid/cmdline" ]] || return 1
    local exe
    exe="$(readlink "/proc/$pid/exe" 2>/dev/null || true)"
    local cmdline
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline")"
    [[ "${exe##*/}" == "wf-recorder" || "$cmdline" == *"/wf-recorder "* || "$cmdline" == *"/wf-recorder" ]] || return 1
    if [[ -n "${state_pid_start:-}" ]]; then
        local current_start
        current_start="$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null || true)"
        [[ "$current_start" == "$state_pid_start" ]] || return 1
    fi
}

clear_state() {
    local inactive_state="${STATE_FILE}.inactive.$$"
    printf 'active=0\n' > "$inactive_state"
    chmod 600 "$inactive_state"
    mv -f -- "$inactive_state" "$STATE_FILE"
}

status() {
    if read_state && owned_pid "$state_pid"; then
        printf 'active=1\npid=%s\ncontroller_pid=%s\nstarted_at=%s\nmode=%s\nsystem_audio=%s\noutput_path=%s\n' \
            "$state_pid" "$state_controller" "$state_started" "$state_mode" "$state_audio" "$state_output"
        return 0
    fi
    clear_state
    printf 'active=0\n'
    return 1
}

if [[ "$operation" == "status" ]]; then
    status
    exit $?
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    printf 'recording-busy\n' >&2
    exit 75
fi

if read_state && owned_pid "$state_pid"; then
    if [[ "$operation" == "start" ]]; then
        printf 'recording-active\n' >&2
        exit 2
    fi
    if [[ "$operation" == "stop" || "$operation" == "toggle" ]]; then
        kill -INT "$state_pid" 2>/dev/null || true
        for _ in {1..50}; do
            if ! owned_pid "$state_pid"; then
                clear_state
                exit 0
            fi
            sleep 0.1
        done
        if owned_pid "$state_pid"; then
            kill -TERM "$state_pid" 2>/dev/null || true
        fi
        exit 0
    fi
fi
clear_state

if [[ "$operation" == "stop" ]]; then
    exit 0
fi

CUSTOM_PATH="$(jq -r '.screenRecord.saveDirectory // empty' "$CONFIG_FILE" 2>/dev/null || true)"
if [[ -z "$CUSTOM_PATH" ]]; then
    CUSTOM_PATH="$(jq -r '.screenRecord.savePath // empty' "$CONFIG_FILE" 2>/dev/null || true)"
fi
RECORDING_DIR="${CUSTOM_PATH:-$HOME/Videos}"
if ! mkdir -p -- "$RECORDING_DIR" || [[ ! -d "$RECORDING_DIR" || ! -w "$RECORDING_DIR" ]]; then
    notify-send "Recording failed" "The recording directory is not writable." -a Recorder 2>/dev/null || true
    exit 1
fi

mode="monitor"
region=""
sound=0
fullscreen=0
while (($#)); do
    case "$1" in
        --region)
            [[ $# -ge 2 ]] || { notify-send "Recording cancelled" "No region specified." -a Recorder 2>/dev/null || true; exit 1; }
            mode="region"; region="$2"; shift 2 ;;
        --fullscreen) fullscreen=1; mode="monitor"; shift ;;
        --sound) sound=1; shift ;;
        *) shift ;;
    esac
done

if ((fullscreen == 1)); then
    mode="monitor"
elif [[ -z "$region" ]]; then
    if ! region="$(slurp 2>/dev/null)"; then
        notify-send "Recording cancelled" "Selection was cancelled." -a Recorder 2>/dev/null || true
        exit 1
    fi
fi

timestamp="$(date '+%Y-%m-%d_%H.%M.%S')"
output="${RECORDING_DIR}/recording_${timestamp}.mp4"
suffix=0
while [[ -e "$output" ]]; do
    suffix=$((suffix + 1))
    output="${RECORDING_DIR}/recording_${timestamp}_${suffix}.mp4"
done

monitor=""
if ((fullscreen == 1)); then
    monitor="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' | head -n1)"
    [[ -n "$monitor" ]] || { notify-send "Recording failed" "No focused monitor was found." -a Recorder 2>/dev/null || true; exit 1; }
fi

audio_source=""
if ((sound == 1)); then
    default_sink="$(pactl get-default-sink 2>/dev/null || true)"
    if [[ -n "$default_sink" ]]; then
        audio_source="$(pactl list sources short 2>/dev/null | awk -v sink="$default_sink" '$2 == sink ".monitor" {print $2; exit}')"
    fi
    [[ -n "$audio_source" ]] || { notify-send "Recording failed" "The default output monitor is unavailable." -a Recorder 2>/dev/null || true; exit 1; }
fi

args=(wf-recorder --pixel-format yuv420p -f "$output")
if ((fullscreen == 1)); then args+=( -o "$monitor" ); else args+=( --geometry "$region" ); fi
if ((sound == 1)); then args+=( --audio="$audio_source" ); fi

9>&- "${args[@]}" &
recorder_pid=$!
controller_pid=$$
started_at="$(date +%s)"
tmp_state="${STATE_FILE}.tmp.$$"
{
    printf 'pid=%s\n' "$recorder_pid"
    printf 'pid_start_ticks=%s\n' "$(awk '{print $22}' "/proc/$recorder_pid/stat" 2>/dev/null || true)"
    printf 'controller_pid=%s\n' "$controller_pid"
    printf 'started_at=%s\n' "$started_at"
    printf 'mode=%s\n' "$mode"
    printf 'system_audio=%s\n' "$sound"
    printf 'output_path=%s\n' "$output"
} > "$tmp_state" && chmod 600 "$tmp_state" && mv -f -- "$tmp_state" "$STATE_FILE"

notify-send "Recording started" "$(basename "$output")" -a Recorder 2>/dev/null || true
exec 9>&-
wait "$recorder_pid"
exit_code=$?
clear_state

if [[ "$exit_code" -eq 0 && -s "$output" ]]; then
    notify-send "Recording stopped" "Saved $(basename "$output")" -a Recorder 2>/dev/null || true
else
    notify-send "Recording failed" "The recorder exited before saving a valid file." -a Recorder 2>/dev/null || true
fi
exit "$exit_code"
