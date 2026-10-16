#!/usr/bin/env bash
# Installs skwd-wall's renderer and daemon into your home,
# from liixini's official GitHub releases, without sudo.
#
#   skwd_install.sh status    installed version, newest release
#   skwd_install.sh install   download, verify, unpack, set up the user service
#
# Everything lands in ~/.local/share/ambxst/skwd-wall/<version>/{bin,lib}, with
# `current` pointing at the version in use, and one user unit,
# ~/.config/systemd/user/ambxst-skwd-walld.service. A system install of skwd
# (AUR, distro package) is never touched; Ambxst prefers it anyway.
#
# Output is line-based for the settings panel:
#   STEP <text>          progress
#   VERSION <tag>        installed version (status)
#   LATEST <tag>         newest release (status)
#   MISSING <lib> <pkg>  a system library the binaries need is not installed
#   DONE <tag>           finished
#   FAIL <text>          stopped; nothing in use was changed
set -uo pipefail

REPO="liixini/skwd-wall"
ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/ambxst/skwd-wall"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT="ambxst-skwd-walld.service"
API="https://api.github.com/repos/$REPO/releases?per_page=10"

fail() { echo "FAIL $*"; exit 1; }
step() { echo "STEP $*"; }

# The newest release that is not a draft (skwd ships everything as pre-releases).
latest_tag() {
    curl -fsSL --max-time 20 -H "Accept: application/vnd.github+json" "$API" 2>/dev/null \
        | python3 -c 'import json,sys
for r in json.load(sys.stdin):
    if not r.get("draft"):
        print(r["tag_name"]); break' 2>/dev/null
}

installed_tag() {
    [ -f "$ROOT/current/VERSION" ] && cat "$ROOT/current/VERSION"
}

# Library -> the package that usually provides it (Arch names, then a hint).
pkg_for() {
    case "$1" in
        libdav1d*) echo "dav1d" ;;
        libva*) echo "libva" ;;
        libyuv*) echo "libyuv" ;;
        libshaderc*) echo "shaderc" ;;
        libvulkan*) echo "vulkan-icd-loader" ;;
        libwayland*) echo "wayland" ;;
        libxkbcommon*) echo "libxkbcommon" ;;
        libpulse*) echo "libpulse" ;;
        libasound*) echo "alsa-lib" ;;
        libdrm*) echo "libdrm" ;;
        libEGL*|libGL*) echo "libglvnd" ;;
        libfontconfig*) echo "fontconfig" ;;
        libz.*) echo "zlib" ;;
        *) echo "?" ;;
    esac
}

check_libs() {
    local dir="$1" missing=0 lib
    for bin in "$dir"/bin/* "$dir"/lib/skwd-paper/skwd-paper-tinier; do
        [ -f "$bin" ] && [ -x "$bin" ] || continue
        while read -r lib; do
            [ -n "$lib" ] || continue
            echo "MISSING $lib $(pkg_for "$lib")"
            missing=1
        done < <(ldd "$bin" 2>/dev/null | awk '/not found/ {print $1}')
    done | sort -u
    return 0
}

write_unit() {
    mkdir -p "$UNIT_DIR"
    cat > "$UNIT_DIR/$UNIT.tmp" <<EOF
# Written by Ambxst: skwd-wall's daemon from
# ~/.local/share/ambxst/skwd-wall/current. Not used when skwd is installed
# system-wide (skwd-walld.service).
[Unit]
Description=skwd-wall wallpaper daemon (Ambxst)
After=graphical-session.target
Conflicts=skwd-walld.service

[Service]
Type=simple
Environment=PATH=$ROOT/current/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$ROOT/current/bin/skwd-walld --wait-for-session
Restart=on-failure
RestartSec=2
Slice=session.slice
EOF
    mv -f "$UNIT_DIR/$UNIT.tmp" "$UNIT_DIR/$UNIT"
    systemctl --user daemon-reload 2>/dev/null || true
}

case "${1:-status}" in
status)
    echo "VERSION $(installed_tag)"
    echo "LATEST $(latest_tag)"
    ;;

install)
    command -v curl >/dev/null || fail "curl is not installed"
    command -v sha256sum >/dev/null || fail "sha256sum is not installed"
    tar --help 2>/dev/null | grep -q zstd || command -v zstd >/dev/null || fail "zstd is not installed (tar needs it to unpack skwd)"
    [ "$(uname -m)" = x86_64 ] || fail "skwd-wall only publishes x86_64 builds"

    step "Finding the newest skwd-wall release"
    tag=$(latest_tag)
    [ -n "$tag" ] || fail "could not reach GitHub to find a release"
    if [ "$(installed_tag)" = "$tag" ] && [ -x "$ROOT/current/bin/skwd-walld" ]; then
        write_unit
        echo "DONE $tag"
        exit 0
    fi
    ver=${tag#v}
    ver=${ver//-/_}
    base="https://github.com/$REPO/releases/download/$tag"

    work=$(mktemp -d "${TMPDIR:-/tmp}/ambxst-skwd.XXXXXX") || fail "no temporary folder"
    trap 'rm -rf "$work"' EXIT

    step "Downloading checksums"
    curl -fsSL --max-time 60 -o "$work/SHA256SUMS" "$base/SHA256SUMS" || fail "could not download SHA256SUMS for $tag"

    for part in deck paper; do
        file="skwd-$part-$ver-1-x86_64.pkg.tar.zst"
        grep -q "  $file\$" "$work/SHA256SUMS" || fail "$tag has no $file"
        step "Downloading skwd-$part ($tag)"
        curl -fSL --max-time 900 -o "$work/$file" "$base/$file" 2>/dev/null || fail "could not download $file"
        step "Verifying skwd-$part"
        (cd "$work" && grep "  $file\$" SHA256SUMS | sha256sum --check --status) || fail "$file does not match its published checksum"
        step "Unpacking skwd-$part"
        mkdir -p "$work/$part"
        tar --zstd -xf "$work/$file" -C "$work/$part" 2>/dev/null \
            || (zstd -dc "$work/$file" | tar -xf - -C "$work/$part") \
            || fail "could not unpack $file"
    done

    step "Installing"
    stage="$ROOT/.$tag.new"
    rm -rf "$stage"
    mkdir -p "$stage/bin" "$stage/lib/skwd-paper" "$stage/share"
    for part in deck paper; do
        cp -a "$work/$part/usr/bin/." "$stage/bin/" 2>/dev/null
        [ -d "$work/$part/usr/lib/skwd-paper" ] && cp -a "$work/$part/usr/lib/skwd-paper/." "$stage/lib/skwd-paper/"
        [ -d "$work/$part/usr/share" ] && cp -a "$work/$part/usr/share/." "$stage/share/"
    done
    for need in skwd-walld skwd-helm skwd-wall-vk skwd-paper-v2; do
        [ -x "$stage/bin/$need" ] || { rm -rf "$stage"; fail "the $tag release is missing $need"; }
    done
    echo "$tag" > "$stage/VERSION"
    rm -rf "${ROOT:?}/$tag"
    mv "$stage" "$ROOT/$tag"
    ln -sfn "$tag" "$ROOT/current.new" && mv -Tf "$ROOT/current.new" "$ROOT/current"
    # Keep the previous version for a quick roll back, nothing older.
    ls -1 "$ROOT" | grep -E '^v[0-9]' | grep -vx "$tag" | sort -V | head -n -1 | while read -r old; do rm -rf "${ROOT:?}/$old"; done

    write_unit
    step "Checking system libraries"
    check_libs "$ROOT/current"
    echo "DONE $tag"
    ;;

*)
    fail "usage: skwd_install.sh status|install"
    ;;
esac
