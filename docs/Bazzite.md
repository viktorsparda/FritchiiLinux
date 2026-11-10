# Lichii on Bazzite, with shader preparation

This branch is [Lichii](https://github.com/zortos293/Lichii) build-150 for Linux, mainly
[Bazzite](https://bazzite.gg) and other Fedora Atomic systems, with one feature Lichii doesn't ship:
**shader preparation from recipes**, as Fritchii does it.

- zmckenney's precompile work ([zortos293/Lichii#895](https://github.com/zortos293/Lichii/pull/895),
  closed upstream without merging) is merged in: a recipe holds the pipelines a game uses, without
  any of the game's code, and is assembled with your own copy of the game into a precompiled
  pipeline file, `precompiled.fork-v54.nx2prep` in the game's shader folder.
- The Ocarina of Time recipe (`dist/recipes`, the one Fritchii ships) is bundled in the AppImage. On
  the game's first boot Lichii finds it, assembles the file with your game, and builds every
  pipeline while "Loading shaders" shows. Later boots skip it until the driver, the build or a
  shader setting changes.
- On Linux the prepared pipelines live in Mesa's shader cache (RADV on AMD, ANV, NVK), which Lichii
  enlarges to 10 GiB for its own process (`MESA_SHADER_CACHE_MAX_SIZE`, unless you set it).
- `tools/linux/bazzite-build.sh` builds it in a Fedora distrobox and packages
  `lichii-linux-x86_64.AppImage`; `tools/linux/bazzite-install.sh` installs it for your user.

Only use games, keys and firmware you dumped from your own console. None of them are included.

## Install

```bash
tools/linux/bazzite-install.sh ~/Downloads/lichii-linux-x86_64.AppImage --steam
```

The AppImage goes to `~/.local/share/lichii-appimage/lichii.AppImage`, the launcher to
`~/.local/bin/lichii`, and Lichii appears in the app menu. `--udev` installs the controller rules,
`--uninstall` removes what the script installed. You can also run the AppImage directly.

## Data

Build-150 keeps its own folders, separate from Eden and Fritchii:

| What | Where |
| --- | --- |
| Saves, keys, NAND, mods | `~/.local/share/lichii` |
| Settings | `~/.config/lichii` |
| Shader caches and the precompiled pipeline file | `~/.local/share/lichii/shader/<title id>` |
| Logs | `~/.local/share/lichii/log/eden_log.txt` |

A folder named `user` in the folder Lichii is started from takes their place (portable mode).

## Shader preparation

- The first boot of Ocarina of Time takes longer: Lichii first finds the game's shaders and builds
  the precompiled file (a minute or two), then compiles the pipelines during "Loading shaders"
  (several minutes, once per driver and GPU).
- The log says what happened: `Precompile recipe ... found ... assembling it`, then
  `Precompile recipe: N pipeline(s) are ready to prepare`, then the preparation itself.
- Recipes are looked for in `~/.local/share/lichii/recipes`, in a `recipes` folder beside the
  `lichii` binary, and in the AppImage. A recipe is used only for its own game and for this build's
  pipeline cache version (54).
- The game list's right-click menu still has **Prepare Precompiled Shaders from Recipe...** for any
  other recipe.
- `EDEN_NX2_AUTO_RECIPE=0` turns the automatic assembly off. `EDEN_NX2_PRECOMPILED=0` skips the
  preparation, and `EDEN_NX2_PRECOMPILED_FORCE=1` runs it again.
- With `MESA_SHADER_CACHE_DISABLE=true` there is no cache to fill, so the preparation is skipped.

## Build from source

```bash
git clone -b claude/lichii-build150-linux https://github.com/viktorsparda/FritchiiLinux.git LichiiLinux
cd LichiiLinux
tools/linux/bazzite-build.sh --appimage
tools/linux/bazzite-install.sh build/bazzite/lichii-linux-x86_64.AppImage
```

On the Bazzite host the script creates a `lichii-build` distrobox matching your Fedora release and
builds with clang inside it. An AppImage built that way needs your Fedora's glibc; the
`bazzite-linux` workflow (run by hand from the Actions tab) builds portable and PGO AppImages on
Ubuntu 24.04 and publishes them as releases.
