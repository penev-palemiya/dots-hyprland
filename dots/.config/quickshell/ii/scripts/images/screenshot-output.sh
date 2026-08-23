#!/usr/bin/env bash
set -euo pipefail

mode=${1:?capture mode is required}
source_to_cleanup=""

if [[ "$mode" == monitor ]]; then
    output=${2:?output name is required}
    directory=${3:?output directory is required}
    copy_saved=${4:?copy policy is required}
    prefix=Screenshot
elif [[ "$mode" == region ]]; then
    source=${2:?source image is required}
    source_to_cleanup=$source
    x=${3:?x is required}
    y=${4:?y is required}
    width=${5:?width is required}
    height=${6:?height is required}
    directory=${7:?output directory is required}
    copy_saved=${8:?copy policy is required}
    prefix=screenshot
else
    echo "Unknown screenshot mode" >&2
    exit 2
fi

if [[ -n "$directory" && "$directory" != /* ]]; then
    echo "Screenshot directory must be absolute" >&2
    exit 2
fi

save=false
if [[ -n "$directory" ]]; then
    save=true
    mkdir -p -- "$directory"
fi

tmp_dir=${directory:-${TMPDIR:-/tmp}}
mkdir -p -- "$tmp_dir"
tmp=$(mktemp "$tmp_dir/.${prefix}.XXXXXX.png")
cleanup() {
    rm -f -- "$tmp"
    if [[ -n "$source_to_cleanup" ]]; then
        rm -f -- "$source_to_cleanup"
    fi
}
trap cleanup EXIT

if [[ "$mode" == monitor ]]; then
    grim -o "$output" "$tmp"
else
    magick "$source" -crop "${width}x${height}+${x}+${y}" +repage "$tmp"
fi

if [[ "$save" == true ]]; then
    timestamp=$(date '+%Y-%m-%d_%H.%M.%S')
    candidate="$directory/${prefix}-${timestamp}.png"
    [[ "$prefix" == Screenshot ]] && candidate="$directory/Screenshot_${timestamp}.png"
    suffix=1
    while ! ln -- "$tmp" "$candidate" 2>/dev/null; do
        candidate="$directory/${prefix}-${timestamp}_${suffix}.png"
        [[ "$prefix" == Screenshot ]] && candidate="$directory/Screenshot_${timestamp}_${suffix}.png"
        suffix=$((suffix + 1))
    done
    if [[ "$copy_saved" == 1 ]]; then
        wl-copy < "$candidate"
    fi
else
    wl-copy < "$tmp"
fi
