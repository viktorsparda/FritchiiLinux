#!/usr/bin/env bash
# shellcheck shell=bash
# SPDX-FileCopyrightText: Copyright 2026 FritchiiLinux contributors
# SPDX-License-Identifier: GPL-3.0-or-later

# Installs a Fritchii AppImage for the current user on Bazzite (or any desktop Linux): the AppImage
# goes to ~/.local/share/fritchii, a launcher to ~/.local/bin/fritchii, and a menu entry and icon
# to ~/.local/share. Nothing is layered onto the system image.

set -euo pipefail

repo=${FRITCHII_REPO:-viktorsparda/FritchiiLinux}
app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fritchii"
bin_dir="$HOME/.local/bin"
apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
icons_dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"
app_id=io.github.frizti.fritchii
# Empty when the script is piped into bash; then the rules and icon come from elsewhere.
src_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fi

usage() {
    cat <<EOF
Usage: $0 [options] [path/to/fritchii.AppImage]

Without a path, the newest release AppImage of $repo is downloaded
(set FRITCHII_REPO=owner/name to use another repository).

  --standard     Download the standard build instead of the PGO one
  --udev         Also install the controller udev rules (asks for sudo)
  --steam        Also add Fritchii to Steam as a non-Steam game, for Gaming Mode
  --uninstall    Remove what this script installed (saves and settings are kept)
  -h, --help     Show this help
EOF
}

appimage=""
variant=-pgo
udev=0
steam=0
uninstall=0
while [ $# -gt 0 ]; do
    case "$1" in
        --standard) variant="" ;;
        --udev) udev=1 ;;
        --steam) steam=1 ;;
        --uninstall) uninstall=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) appimage=$(realpath "$1") ;;
    esac
    shift
done

if [ "$uninstall" = 1 ]; then
    rm -f "$bin_dir/fritchii" "$apps_dir/$app_id.desktop" "$icons_dir/$app_id.png" \
        "$app_dir/fritchii.AppImage"
    rmdir "$app_dir" 2>/dev/null || true
    command -v update-desktop-database > /dev/null && update-desktop-database "$apps_dir" || true
    echo "Removed Fritchii. Saves and settings in ~/.local/share/fritchii and ~/.config/fritchii are kept."
    exit 0
fi

mkdir -p "$app_dir" "$bin_dir" "$apps_dir" "$icons_dir"
target="$app_dir/fritchii.AppImage"

if [ -z "$appimage" ]; then
    arch=$(uname -m)
    echo "Looking up the newest release of $repo"
    if ! releases=$(curl -fsSL "https://api.github.com/repos/$repo/releases?per_page=20"); then
        echo "Could not list the releases of $repo. Check your connection, or pass a downloaded AppImage." >&2
        exit 1
    fi
    url=$(python3 -c '
import json, sys
arch, variant = sys.argv[1], sys.argv[2]
names = [f"fritchii-linux-{arch}{variant}.AppImage", f"fritchii-linux-{arch}.AppImage"]
for release in json.load(sys.stdin):
    if release.get("draft"):
        continue
    assets = {a["name"]: a["browser_download_url"] for a in release.get("assets", [])}
    for name in names:
        if name in assets:
            print(assets[name])
            sys.exit(0)
' "$arch" "$variant" <<< "$releases") || true
    if [ -z "$url" ]; then
        echo "No Linux AppImage found in the releases of $repo." >&2
        echo "Build one with tools/linux/bazzite-build.sh --appimage and pass its path." >&2
        exit 1
    fi
    echo "Downloading $url"
    curl -fL --progress-bar -o "$target.part" "$url"
    mv "$target.part" "$target"
else
    test -f "$appimage" || { echo "$appimage does not exist" >&2; exit 1; }
    cp "$appimage" "$target.part"
    mv "$target.part" "$target"
fi
chmod +x "$target"

# The AppImage runtime mounts itself through libfuse2. Without it, the image unpacks itself to a
# temporary directory on each start instead, which is slower but works.
cat > "$bin_dir/fritchii" <<EOF
#!/bin/sh
if ! { ldconfig -p 2>/dev/null | grep -q 'libfuse\.so\.2'; } && [ ! -e /usr/lib64/libfuse.so.2 ]; then
    export APPIMAGE_EXTRACT_AND_RUN=1
fi
exec "$target" "\$@"
EOF
chmod +x "$bin_dir/fritchii"

if [ -n "$src_dir" ] && [ -f "$src_dir/dist/fritchii.png" ]; then
    cp "$src_dir/dist/fritchii.png" "$icons_dir/$app_id.png"
else
    tmp=$(mktemp -d)
    # The top-level icon is a symlink into usr/share/icons, so take the real file from there.
    (cd "$tmp" && "$target" --appimage-extract "usr/share/icons/*" > /dev/null 2>&1) || true
    icon=$(find "$tmp/squashfs-root/usr/share/icons" -name "$app_id.png" -type f 2>/dev/null |
        sort -V | tail -1)
    if [ -n "$icon" ]; then
        cp "$icon" "$icons_dir/$app_id.png"
    fi
    rm -rf "$tmp"
fi

cat > "$apps_dir/$app_id.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Fritchii
GenericName=Switch Emulator
Comment=Experimental Nintendo Switch and Switch 2 emulator
Icon=$app_id
TryExec=$bin_dir/fritchii
Exec=$bin_dir/fritchii %f
Categories=Game;Emulator;Qt;
MimeType=application/x-nx-nro;application/x-nx-nso;application/x-nx-nsp;application/x-nx-xci;
Keywords=Nintendo;Switch;Fritchii;Lichii;
StartupWMClass=lichii
EOF
command -v update-desktop-database > /dev/null && update-desktop-database "$apps_dir" || true
command -v gtk-update-icon-cache > /dev/null &&
    gtk-update-icon-cache -q -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" || true

if [ "$udev" = 1 ]; then
    rules="$src_dir/dist/72-eden-input.rules"
    if [ -z "$src_dir" ] || [ ! -f "$rules" ]; then
        rules=$(mktemp)
        curl -fsSL -o "$rules" "https://raw.githubusercontent.com/$repo/HEAD/dist/72-eden-input.rules"
    fi
    # /etc stays writable on Bazzite's image, so the rules survive updates.
    sudo install -m 0644 "$rules" /etc/udev/rules.d/72-eden-input.rules
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=hidraw
    echo "Installed the controller udev rules. Reconnect your controllers."
fi

if [ "$steam" = 1 ]; then
    if command -v steamos-add-to-steam > /dev/null; then
        steamos-add-to-steam "$apps_dir/$app_id.desktop"
    else
        echo "steamos-add-to-steam is not available. In Steam choose Games > Add a Non-Steam Game"
        echo "and pick Fritchii, or browse to $bin_dir/fritchii."
    fi
fi

echo "Installed Fritchii to $target"
case ":$PATH:" in
    *":$bin_dir:"*) echo "Run it from the app menu or with: fritchii" ;;
    *) echo "Run it from the app menu or with: $bin_dir/fritchii" ;;
esac
