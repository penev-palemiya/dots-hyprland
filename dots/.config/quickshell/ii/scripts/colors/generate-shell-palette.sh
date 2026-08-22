#!/usr/bin/env bash

set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
OUTPUT_FILE="$XDG_STATE_HOME/quickshell/user/generated/colors.json"
LOCK_DIR="$OUTPUT_FILE.lock"

mode="dark"
scheme="scheme-neutral"
source_color=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode) mode="$2"; shift 2 ;;
        --scheme) scheme="$2"; shift 2 ;;
        --color) source_color="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

[[ "$mode" == "dark" || "$mode" == "light" ]] || exit 2
[[ "$scheme" =~ ^scheme-(content|expressive|fidelity|fruit-salad|monochrome|neutral|rainbow|tonal-spot|vibrant|smart)$ ]] || exit 2
if [[ -n "$source_color" && ! "$source_color" =~ ^#[A-Fa-f0-9]{6}$ ]]; then
    exit 2
fi

wallpaper="$(jq -r '.background.wallpaperPath // empty' "$CONFIG_FILE")"
if [[ -z "$source_color" && ! -f "$wallpaper" ]]; then
    echo "Wallpaper source is unavailable." >&2
    exit 3
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "A palette generation is already running." >&2
    exit 75
fi

work_dir="$(mktemp -d)"
cleanup() {
    rm -rf "$work_dir" "$LOCK_DIR"
}
trap cleanup EXIT

cat > "$work_dir/config.toml" <<EOF
[config]
version_check = false

[templates.m3colors]
input_path = '$XDG_CONFIG_HOME/matugen/templates/colors.json'
output_path = '$work_dir/colors.json'
EOF

args=(--config "$work_dir/config.toml" --source-color-index 0 --mode "$mode" --type "$scheme")
if [[ -n "$source_color" ]]; then
    args+=(color hex "$source_color")
else
    args+=(image "$wallpaper")
fi

matugen "${args[@]}" >/dev/null
jq -e 'type == "object" and (.background | type == "string") and (.primary | type == "string")' "$work_dir/colors.json" >/dev/null
mkdir -p "$(dirname "$OUTPUT_FILE")"
mv -f "$work_dir/colors.json" "$OUTPUT_FILE"
