#!/usr/bin/env bash
# Keeps the material for exactly ONE wallpaper: a private copy of the picture
# itself, plus its pre-blurred variant.
#
# Two reasons this exists:
#
#  - Blur is a pure function of (picture, parameters). Six frosted surfaces were
#    each recomputing the same blur continuously on the GPU. Doing it once, on
#    disk, turns every one of them into a plain image crop.
#  - The private copy means deleting or moving the original file no longer takes
#    the wallpaper down with it.
#
# Filenames are fixed and every rebuild wipes the previous set, so this
# directory holds one wallpaper's material and cannot grow into a history.
#
# Usage:  material.sh <wallpaper-path> <material-dir>
# Prints: the copy's path and the blurred path, one per line.
# Exit 1: no usable material (no original, and nothing cached).

set -uo pipefail

src=${1:-}
dir=${2:-}
[ -n "$src" ] && [ -n "$dir" ] || { echo "usage: material.sh <wallpaper> <dir>" >&2; exit 2; }

# The blurred copy carries no high frequencies, so a quarter of each dimension
# is indistinguishable from full size and a fraction of the bytes.
BLUR_SCALE="25%"
BLUR_SIGMA="0x20"
PARAMS="v1:${BLUR_SCALE}:${BLUR_SIGMA}"

mkdir -p "$dir" || exit 1

cached_source() {
    for candidate in "$dir"/source.*; do
        [ -f "$candidate" ] && { printf '%s' "$candidate"; return 0; }
    done
    return 1
}

emit_cached() {
    local copy
    copy=$(cached_source) || return 1
    [ -f "$dir/blur.png" ] || return 1
    printf '%s\n%s\n' "$copy" "$dir/blur.png"
    return 0
}

# The original is gone - this is the case the copy exists for.
if [ ! -f "$src" ]; then
    emit_cached && exit 0
    exit 1
fi

mtime=$(stat -c %Y -- "$src" 2>/dev/null) || exit 1
key=$(printf '%s' "$src:$mtime:$PARAMS" | sha1sum | cut -c1-16)

if [ "$(cat "$dir/key" 2>/dev/null)" = "$key" ]; then
    emit_cached && exit 0
fi

# Rebuild. Wiping first is what keeps this a cache of one rather than a history.
rm -f "$dir"/source.* "$dir/blur.png" "$dir/key"

ext=${src##*.}
case "$ext" in
    "$src"|"") ext="img" ;;
esac
copy="$dir/source.$ext"

cp -- "$src" "$copy" || exit 1
if ! magick "$copy" -resize "$BLUR_SCALE" -blur "$BLUR_SIGMA" -strip "$dir/blur.png"; then
    # Keep the copy even if blurring failed: the resilience half still works,
    # and callers fall back to blurring live.
    rm -f "$dir/blur.png"
    printf '%s\n\n' "$copy"
    exit 0
fi

printf '%s' "$key" > "$dir/key"
printf '%s\n%s\n' "$copy" "$dir/blur.png"
