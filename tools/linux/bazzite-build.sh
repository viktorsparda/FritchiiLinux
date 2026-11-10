#!/usr/bin/env bash
# shellcheck shell=bash
# SPDX-FileCopyrightText: Copyright 2026 FritchiiLinux contributors
# SPDX-License-Identifier: GPL-3.0-or-later

# Builds Lichii on Bazzite (or any Fedora system) and optionally packages an AppImage.
#
# Bazzite's base image is immutable, so on the host this script creates a Fedora distrobox
# matching the host's Fedora release and re-runs itself inside it. The source tree lives in your
# home directory, which distrobox shares, so the build ends up in the same place either way.

set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [options]

  --appimage           Also package build/<dir>/lichii-linux-<arch>.AppImage
  --build-dir <dir>    Build directory (default: build/bazzite)
  --jobs <n>           Parallel jobs (default: all cores)
  --debug              RelWithDebInfo instead of Release
  --no-deps            Don't install packages with dnf
  --no-container       Build on this system even if it is an immutable host
  --box <name>         Distrobox name (default: lichii-build)
  --fedora <version>   Fedora release for the distrobox (default: the host's)
  -h, --help           Show this help
EOF
}

src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
build_dir="$src_dir/build/bazzite"
jobs=$(nproc)
build_type=Release
appimage=0
install_deps=1
use_container=auto
box=lichii-build
fedora=""
args=("$@")

while [ $# -gt 0 ]; do
    case "$1" in
        --appimage) appimage=1 ;;
        --build-dir) build_dir=$(realpath -m "$2"); shift ;;
        --jobs) jobs=$2; shift ;;
        --debug) build_type=RelWithDebInfo ;;
        --no-deps) install_deps=0 ;;
        --no-container) use_container=no ;;
        --box) box=$2; shift ;;
        --fedora) fedora=$2; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

in_container() {
    [ -e /run/.containerenv ] || [ -e /.dockerenv ]
}

immutable_host() {
    [ -e /run/ostree-booted ]
}

if [ "$use_container" = auto ] && ! in_container && immutable_host; then
    if ! command -v distrobox > /dev/null; then
        echo "distrobox is missing. Bazzite ships it; on other atomic systems install it first," >&2
        echo "or pass --no-container if the build tools are already on this system." >&2
        exit 1
    fi
    if [ -z "$fedora" ]; then
        fedora=$(. /etc/os-release && echo "${VERSION_ID:-43}")
    fi
    if ! distrobox list --no-color 2>/dev/null | awk -F'|' '{gsub(/ /, "", $2); print $2}' |
        grep -qx "$box"; then
        echo "Creating distrobox $box (Fedora $fedora)"
        distrobox create --yes --name "$box" \
            --image "registry.fedoraproject.org/fedora-toolbox:$fedora"
    fi
    exec distrobox enter "$box" -- bash "$src_dir/tools/linux/bazzite-build.sh" \
        --no-container "${args[@]}"
fi

if [ "$install_deps" = 1 ]; then
    if ! command -v dnf > /dev/null; then
        echo "dnf not found: this script installs Fedora packages. Pass --no-deps to skip that." >&2
        exit 1
    fi
    sudo=""
    [ "$(id -u)" -ne 0 ] && sudo=sudo
    # Anything missing from a given Fedora release is built from the bundled copy instead.
    $sudo dnf install -y --skip-unavailable \
        git cmake ninja-build clang lld llvm make autoconf automake libtool nasm patch \
        pkgconf-pkg-config which file curl ccache desktop-file-utils patchelf \
        glslang spirv-tools spirv-headers-devel \
        qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtcharts-devel qt6-qttools-devel \
        qt6-qtwayland-devel qt6-qtsvg-devel \
        boost-devel fmt-devel lz4-devel libzstd-devel zlib-ng-compat-devel openssl-devel \
        libusb1-devel opus-devel enet-devel json-devel simpleini-devel gamemode-devel SDL3-devel \
        libva-devel libvdpau-devel pulseaudio-libs-devel alsa-lib-devel systemd-devel \
        libxkbcommon-devel libxkbcommon-x11-devel mesa-libGL-devel mesa-libGLU-devel \
        mesa-libEGL-devel vulkan-loader-devel libdrm-devel \
        fuse-libs xcb-util-cursor xcb-util-wm xcb-util-image xcb-util-keysyms xcb-util-renderutil
fi

# Fedora's xbyak is older than the one dynarmic needs, and its FFmpeg (ffmpeg-free) has no
# H.264/HEVC decoders, which game movies use. Both come from the bundled copies. Clang avoids
# the GCC 13 miscompile behind black screens on Linux (zortos293/Lichii#532, #524).
cmake -S "$src_dir" -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE="$build_type" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
    -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
    -DBUILD_TESTING=OFF \
    -DYUZU_TESTS=OFF \
    -DYUZU_CMD=ON \
    -DYUZU_ROOM=OFF \
    -DYUZU_ROOM_STANDALONE=OFF \
    -DYUZU_USE_BUNDLED_QT=OFF \
    -DYUZU_USE_BUNDLED_SDL3=OFF \
    -DYUZU_USE_BUNDLED_FFMPEG=ON \
    -Dxbyak_FORCE_BUNDLED=ON \
    -DVulkanHeaders_FORCE_BUNDLED=ON \
    -DVulkanUtilityLibraries_FORCE_BUNDLED=ON \
    -DUSE_DISCORD_PRESENCE=OFF \
    -DENABLE_UPDATE_CHECKER=OFF \
    -DUSE_CCACHE=ON

cmake --build "$build_dir" --target yuzu yuzu-cmd --parallel "$jobs"

bin="$build_dir/bin"
test -x "$bin/lichii"
test -x "$bin/eden-cli"
echo "Built $bin/lichii and $bin/eden-cli"

if [ "$appimage" = 1 ]; then
    arch=$(uname -m)
    tools="$build_dir/linuxdeploy"
    mkdir -p "$tools"
    for tool in linuxdeploy linuxdeploy-plugin-qt; do
        if [ ! -x "$tools/$tool-$arch.AppImage" ]; then
            curl -fsSL -o "$tools/$tool-$arch.AppImage" \
                "https://github.com/linuxdeploy/$tool/releases/download/continuous/$tool-$arch.AppImage"
            chmod +x "$tools/$tool-$arch.AppImage"
        fi
    done
    icon="$tools/io.github.zortos293.lichii.png"
    cp "$src_dir/dist/lichii.png" "$icon"
    desktop="$src_dir/dist/io.github.zortos293.lichii.desktop"
    appdir="$build_dir/AppDir"
    rm -rf "$appdir"
    output="$build_dir/lichii-linux-$arch.AppImage"
    # Strip a copy so the build tree keeps its symbols.
    mkdir -p "$tools/bin"
    cp "$bin/lichii" "$bin/eden-cli" "$tools/bin/"
    strip "$tools/bin/lichii" "$tools/bin/eden-cli"
    # Shader precompile recipes, assembled with the player's game on its first boot
    # (MainWindow::AutoPrepareShadersFromRecipe).
    if compgen -G "$src_dir/dist/recipes/*.nx2recipe" > /dev/null; then
        mkdir -p "$appdir/usr/share/lichii/recipes"
        cp "$src_dir"/dist/recipes/*.nx2recipe "$appdir/usr/share/lichii/recipes/"
    fi
    (
        cd "$build_dir"
        export APPIMAGE_EXTRACT_AND_RUN=1
        # linuxdeploy's bundled strip can't read Fedora's .relr.dyn sections; the libraries
        # are already stripped.
        export NO_STRIP=1
        # The Qt plugin's own patchelf (0.15) corrupts libraries linked with packed relative
        # relocations (DT_RELR), which Fedora uses; the bundled xcb libraries then crash on load.
        if command -v patchelf > /dev/null; then
            PATCHELF=$(command -v patchelf)
            export PATCHELF
        else
            echo "patchelf is missing: install it, or the AppImage may crash on start" >&2
        fi
        QMAKE=$(command -v qmake6 || command -v qmake-qt6 || echo /usr/lib64/qt6/bin/qmake)
        export QMAKE
        export EXTRA_QT_MODULES=waylandcompositor
        # Qt 6.10 merged libqwayland-egl.so and libqwayland-generic.so into libqwayland.so.
        plugins_dir=$("$QMAKE" -query QT_INSTALL_PLUGINS)/platforms
        wayland=""
        for plugin in libqwayland.so libqwayland-egl.so libqwayland-generic.so; do
            [ -f "$plugins_dir/$plugin" ] && wayland="${wayland:+$wayland;}$plugin"
        done
        export EXTRA_PLATFORM_PLUGINS="$wayland"
        export LDAI_OUTPUT="$output"
        export OUTPUT="$output"
        export ARCH="$arch"
        "$tools/linuxdeploy-$arch.AppImage" --appdir "$appdir" \
            --executable "$tools/bin/lichii" \
            --executable "$tools/bin/eden-cli" \
            --desktop-file "$desktop" \
            --icon-file "$icon" \
            --plugin qt \
            --output appimage
    )
    test -s "$output"
    echo "Packaged $output"
    echo "Install it with: $src_dir/tools/linux/bazzite-install.sh $output"
fi
