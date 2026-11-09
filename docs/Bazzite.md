# Lichii on Bazzite

This fork packages Lichii for [Bazzite](https://bazzite.gg) and other Fedora Atomic systems. Lichii's
Linux code is upstream's ([zortos293/Lichii](https://github.com/zortos293/Lichii)). What this fork adds:

- `tools/linux/bazzite-install.sh` installs an AppImage for your user, with a launcher, a menu
  entry, and optionally the controller rules and a Steam shortcut. Nothing is layered onto the
  system image.
- `tools/linux/bazzite-build.sh` builds from source inside a Fedora distrobox that matches your
  Bazzite release, and can package the result as an AppImage.
- The `bazzite-linux` workflow publishes Linux AppImages as releases of this repository. Their
  in-app updater follows this repository's releases.

Lichii is experimental. Only use games, keys and firmware you dumped from your own console. None
of them are included.

## Install

In a terminal (Konsole, or Ptyxis on GNOME):

```bash
curl -fsSL https://raw.githubusercontent.com/viktorsparda/FritchiiLinux/nx2/tools/linux/bazzite-install.sh | bash
```

This downloads the newest PGO AppImage from this repository's releases to
`~/.local/share/fritchii/lichii.AppImage`, adds `~/.local/bin/lichii`, and adds Lichii to the app
menu. Options (with `bash -s --` when piping, e.g. `| bash -s -- --steam`):

| Option | Effect |
| --- | --- |
| `--standard` | Standard build instead of PGO. Try it if the PGO build misbehaves on your machine. |
| `--steam` | Adds Lichii to Steam as a non-Steam game, for Gaming Mode. |
| `--udev` | Installs `72-eden-input.rules` to `/etc/udev/rules.d` (asks for sudo). Bazzite already ships rules for most controllers; use this only if motion controls or a controller isn't detected. |
| `--uninstall` | Removes the AppImage, launcher and menu entry. Saves and settings stay. |
| `path/to/file.AppImage` | Installs that AppImage instead of downloading one. |

You can also just download `lichii-linux-x86_64-pgo.AppImage` from the releases page, mark it
executable (`chmod +x`, or Properties > Permissions in the file manager) and run it, or add it with
Gear Lever from Bazaar.

If libfuse2 is missing, the launcher sets `APPIMAGE_EXTRACT_AND_RUN=1`. The AppImage then unpacks
itself on each start, which is slower but needs no FUSE.

## Setup

1. Start Lichii and point it at your `prod.keys` and firmware when it asks (or use
   **Tools > Install Decryption Keys** and **Tools > Install Firmware**).
2. Double-click the empty game list (or its **Add New Game Directory** entry) to add your games folder.
3. Configure controllers in **Emulation > Configure... > Controls**.

Data uses upstream's directory names:

| What | Where |
| --- | --- |
| Saves, keys, NAND, mods | `~/.local/share/eden` |
| Settings | `~/.config/eden` |
| Shader caches | `~/.cache/eden` |
| Logs | `~/.local/share/eden/log/eden_log.txt` |

## Gaming Mode (Steam Deck, handhelds, HTPC)

1. In Desktop Mode, run the installer with `--steam`, or in Steam use **Games > Add a Non-Steam
   Game to My Library** and pick Lichii.
2. Set up keys, firmware and games in Desktop Mode first. The Qt settings windows are awkward to
   use with a controller.
3. To start a game straight from Steam, set the shortcut's target to `~/.local/bin/lichii` and its
   launch options to `-f -g "/path/to/game.nsp"`. `-f` starts fullscreen.
4. Pick a gamepad controller layout in Steam Input, so the Steam Deck's controls reach Lichii as a
   controller.

If the window is black or misplaced under Gaming Mode's compositor, enable
**Force X11 as Graphics Backend** in **Emulation > Configure... > General**, or put
`QT_QPA_PLATFORM=xcb %command%` in the shortcut's launch options.

## AMD FSR 4 (Ocarina of Time)

Ocarina of Time renders with its own DLSS pass, which Lichii can replace with AMD's upscalers
(upstream [#695](https://github.com/zortos293/Lichii/pull/695) and
[#915](https://github.com/zortos293/Lichii/pull/915)). Turn on
**Emulation > Configure... > Graphics > Use AMD FSR 4 / FSR 3.1 upscaling in Ocarina of Time**
and start the game.

FSR 4 comes from an FFX API upscaler library named `amd_fidelityfx_upscaler_vk.so`. AMD ships
FSR 4 for Windows only, so on Linux this is [fsr4-vk](https://github.com/Astyyyyy/fsr4-vk), an
independent Vulkan port of FSR 4.1.1 built from AMD's SDK 2.3.0 model (not affiliated with AMD).
Lichii loads the first of:

1. the file named by `EDEN_NX2_FSR4_LIB`;
2. `~/.local/share/eden/amd_fidelityfx_upscaler_vk.so`;
3. the copy shipped with the emulator (`usr/lib` inside an AppImage built with `--fsr4-lib`).

Without the library, or when FSR 4 can't start on the GPU, Lichii uses AMD FSR 3.1, which runs on
any Vulkan GPU. The log says which one runs: `FSR 4: upscaler library ...` and
`FSR 4: context ...` for FSR 4, `... using FSR 3.1` otherwise.

fsr4-vk runs the FP8 model on GPUs with `VK_EXT_shader_float8` and FP8 cooperative matrices
(RDNA 4 on a current Mesa) and the INT8 model elsewhere; `FSR4_VK_MODEL=int8` or `fp8` overrides
the choice. Lichii enables `VK_EXT_shader_float8` on the device when the driver offers it: the FP8
model draws a black picture without it (CheezerWheezer/Lichii ab795780).

To build the library yourself (in the same distrobox as the emulator, plus `llvm`):

```bash
git clone --recurse-submodules https://github.com/Astyyyyy/fsr4-vk.git
cd fsr4-vk
python3 tools/setup.py --dll /path/to/amd_fidelityfx_upscaler_dx12.dll
bash tools/build/linux.sh
```

The DLL is `Kits/FidelityFX/signedbin/amd_fidelityfx_upscaler_dx12.dll` from AMD's
[FidelityFX SDK v2.3.0](https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/releases/tag/v2.3.0)
(SHA-256 `d0dcccc74a43c44ba435b7a369b456e0970d8a4464e4bd683119b374f2c9fb46`; setup checks it).
Then either copy `build/linux/amd_fidelityfx_upscaler_vk.so` to `~/.local/share/eden/`, or bundle
it: `tools/linux/bazzite-build.sh --appimage --fsr4-lib /path/to/fsr4-vk/build/linux/amd_fidelityfx_upscaler_vk.so`.

## Updates

Release builds check this repository for new releases and can replace the installed AppImage in
place, keeping one rollback copy. Running the installer again also updates it.

## Build from source

```bash
git clone https://github.com/viktorsparda/FritchiiLinux.git
cd FritchiiLinux
tools/linux/bazzite-build.sh --appimage
tools/linux/bazzite-install.sh build/bazzite/lichii-linux-x86_64.AppImage
```

On the Bazzite host, the script creates a `fritchii-build` distrobox from
`registry.fedoraproject.org/fedora-toolbox:<your Fedora release>`, installs the build dependencies
with dnf inside it, and builds with clang. On a normal Fedora system, or inside a box you made
yourself, it builds in place. `--help` lists the options.

Two dependencies always come from the bundled copies: Fedora's `xbyak-devel` is older than
dynarmic needs, and Fedora's FFmpeg (`ffmpeg-free`) can't decode the H.264/HEVC movies games use.
The first build downloads them, along with any other dependency Fedora doesn't package, into
`.cache/cpm`.

A local build has the update checker turned off. Rebuild, or reinstall a release, to update it.
An AppImage built this way needs the glibc of the Fedora release it was built on, so it is for
your own machine; the release AppImages are built on Ubuntu 24.04 to run almost anywhere.

## Troubleshooting

- **Game loads (music plays) but the screen stays black, and the log has
  `Native MME (split front) failed ... instruction outside uploaded RAM`.** Set
  **DMA Accuracy** in **Configure... > Graphics > Advanced** to **Safe** for that game
  ([zortos293/Lichii#532](https://github.com/zortos293/Lichii/issues/532)).
- **`Failed to open VDPAU backend libvdpau_nvidia.so` / `Failed to initialise VAAPI`.** These
  are informational on most systems and not the cause of a black screen
  ([zortos293/Lichii#605](https://github.com/zortos293/Lichii/issues/605)).
- **The tar.gz fails with ``version `Qt_6.8' not found``.** The tar.gz uses your system's Qt;
  use the AppImage instead, which bundles Qt
  ([zortos293/Lichii#901](https://github.com/zortos293/Lichii/issues/901)).
- **GPU hangs or device loss on AMD.** These are upstream renderer issues, not packaging ones.
  Check upstream's open issues for your game and GPU.

When you report a problem, include `eden_log.txt`, your Bazzite image (`rpm-ostree status`), GPU,
and whether you were in Desktop or Gaming Mode.
