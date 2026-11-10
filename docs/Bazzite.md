# Fritchii on Bazzite

[Fritchii](https://github.com/Frizti/Fritchii) is Frizti's fork of Lichii, released for Windows.
This branch packages it for Linux, mainly [Bazzite](https://bazzite.gg) and other Fedora Atomic
systems. The emulator code is Fritchii's own (currently the `fritchii-v5.7` tag); what this branch adds:

- `tools/linux/bazzite-build.sh` builds Fritchii inside a Fedora distrobox that matches your Bazzite
  release, and can package it as `fritchii-linux-x86_64.AppImage`.
- `tools/linux/bazzite-install.sh` installs that AppImage for your user, with a `fritchii`
  launcher, a menu entry with Fritchii's icon, and optionally the controller rules and a Steam
  shortcut. Nothing is layered onto the system image.
- The `bazzite-linux` workflow builds Linux AppImages on Ubuntu 24.04 (glibc 2.39, so they run on
  almost any current distribution) and publishes them as releases of this repository.

Only use games, keys and firmware you dumped from your own console. None of them are included.

## Install

From a downloaded or locally built AppImage, in a terminal (Konsole, or Ptyxis on GNOME) inside a
clone of this branch:

```bash
tools/linux/bazzite-install.sh ~/Downloads/fritchii-linux-x86_64.AppImage --steam
```

Or let the installer download the newest release AppImage of this repository:

```bash
curl -fsSL https://raw.githubusercontent.com/viktorsparda/FritchiiLinux/claude/fritchii-v5.5-linux/tools/linux/bazzite-install.sh | bash
```

The AppImage goes to `~/.local/share/fritchii/fritchii.AppImage`, the launcher to
`~/.local/bin/fritchii`, and Fritchii appears in the app menu. Options (with `bash -s --` when
piping, e.g. `| bash -s -- --steam`):

| Option | Effect |
| --- | --- |
| `--standard` | Standard build instead of PGO, when downloading. |
| `--steam` | Adds Fritchii to Steam as a non-Steam game, for Gaming Mode. |
| `--udev` | Installs `72-eden-input.rules` to `/etc/udev/rules.d` (asks for sudo). Bazzite already ships rules for most controllers; use this only if motion controls or a controller isn't detected. |
| `--uninstall` | Removes the AppImage, launcher and menu entry. Saves and settings stay. |

You can also mark the AppImage executable (`chmod +x`, or Properties > Permissions in the file
manager) and run it directly, or add it with Gear Lever from Bazaar. If libfuse2 is missing, the
launcher sets `APPIMAGE_EXTRACT_AND_RUN=1`, and the AppImage unpacks itself on each start instead.

## Data

Fritchii keeps Lichii's (and Eden's) folders, so it shares saves, keys and settings with a Lichii
install on the same account:

| What | Where |
| --- | --- |
| Saves, keys, NAND, mods | `~/.local/share/eden` |
| Settings | `~/.config/eden` |
| Shader caches | `~/.cache/eden` |
| Logs | `~/.local/share/eden/log/eden_log.txt` |

A folder named `user` in the folder Fritchii is started from takes their place (portable mode), as
on Windows next to the executable.

## Preparing shaders

As on Windows, the first start of Ocarina of Time shows a "Preparing shaders" screen (about 15
minutes on an 8-core CPU, once per driver and GPU); after that new areas don't stall on shader
builds. It comes from Fritchii's recipe for the game, `OoT v131072 (cache v54).nx2recipe`, which
the AppImage carries in `usr/share/fritchii/recipes` (the Windows zip has it in `recipes` beside
`lichii.exe`). Fritchii also reads recipes from `~/.local/share/eden/recipes` and from a `recipes`
folder beside the `lichii` binary.

The prepared shaders live in the driver's own cache. With Mesa's drivers (RADV on AMD, ANV, NVK)
that is `~/.cache/mesa_shader_cache`, which Fritchii enlarges to 10 GiB for its own process
(`MESA_SHADER_CACHE_MAX_SIZE`, unless you set it). With `MESA_SHADER_CACHE_DISABLE=true` there is
no cache to fill, so Fritchii skips the preparation.

## Anti-aliasing in Ocarina of Time

**Ocarina of Time anti-aliasing** offers the game's own network, AMD FSR 3.1 and AMD FSR 4. FSR 3.1
works on Linux. Fritchii's FSR 4 loads AMD's signed Windows runtime, which doesn't exist for Linux,
so on Linux the FSR 4 choice falls back to FSR 3.1 (the log says `using FSR 3.1`).

## Gaming Mode (Steam Deck, handhelds, HTPC)

1. In Desktop Mode, run the installer with `--steam`, or in Steam use **Games > Add a Non-Steam
   Game to My Library** and pick Fritchii.
2. Set up keys, firmware and games in Desktop Mode first.
3. To start a game straight from Steam, set the shortcut's target to `~/.local/bin/fritchii` and
   its launch options to `-f -g "/path/to/game.nsp"`. `-f` starts fullscreen.
4. Pick a gamepad controller layout in Steam Input, so the Steam Deck's controls reach Fritchii.

If the window is black or misplaced under Gaming Mode's compositor, put
`QT_QPA_PLATFORM=xcb %command%` in the shortcut's launch options.

## Updates

Fritchii's in-app updater only knows the Windows zips, so the Linux builds have it turned off.
Download a newer AppImage and run the installer again.

## Build from source

```bash
git clone -b claude/fritchii-v5.5-linux https://github.com/viktorsparda/FritchiiLinux.git
cd FritchiiLinux
tools/linux/bazzite-build.sh --appimage
tools/linux/bazzite-install.sh build/bazzite/fritchii-linux-x86_64.AppImage
```

On the Bazzite host, the script creates a `fritchii-build` distrobox from
`registry.fedoraproject.org/fedora-toolbox:<your Fedora release>`, installs the build dependencies
with dnf inside it, and builds with clang. On a normal Fedora system, or inside a box you made
yourself, it builds in place. `--help` lists the options.

Two dependencies always come from the bundled copies: Fedora's `xbyak-devel` is older than
dynarmic needs, and Fedora's FFmpeg (`ffmpeg-free`) can't decode the H.264/HEVC movies games use.
The first build downloads them, along with any other dependency Fedora doesn't package, into
`.cache/cpm`.

An AppImage built this way needs the glibc of the Fedora release it was built on, so it is for
your own machine; the release AppImages are built on Ubuntu 24.04 to run almost anywhere.

## Troubleshooting

- **Game loads (music plays) but the screen stays black, and the log has
  `Native MME (split front) failed ... instruction outside uploaded RAM`.** Set **DMA Accuracy**
  to **Safe** for that game ([zortos293/Lichii#532](https://github.com/zortos293/Lichii/issues/532)).
- **`Failed to open VDPAU backend libvdpau_nvidia.so` / `Failed to initialise VAAPI`.** These
  are informational on most systems and not the cause of a black screen.
- **`WARNING: radv is not a conformant Vulkan implementation`.** Mesa prints this for GPUs whose
  conformance tests haven't been submitted for that Mesa version; it doesn't affect Fritchii.

When you report a problem, include `eden_log.txt`, your Bazzite image (`rpm-ostree status`), GPU,
and whether you were in Desktop or Gaming Mode.
