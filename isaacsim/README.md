# Isaac Sim

## Usage
```bash
# Runs isaac-sim.sh (isaacsim.exp.full.kit)
isaacsim

# Direct access to kit binary
isaacsim-kit

# Direct access to python executable
isaacsim-python

# Runs the streaming client (also installed with a .desktop file)
isaacsim-webrtc-streaming-client

# Get isaacsim environment (useful for isaaclab, extension development, etc.)
source $(which isaacsim-env)

# Any other scripts in the installation directory should technically be working
# (except `jupyter_notebook.sh`, see Known issues)

# Navigate to isaacsim directory with
cd $(dirname $(realpath $(which isaacsim)))
# Run script
./isaac-sim.fabric.sh
./isaac-sim.newton.sh
```

## Changes

1. Dynamic linking 
   isn't supported on Nix that's why we use patchelf to set interpreter paths
   to prebuilt binaries like `isaacsim.ros2.core.check` which are invoked by
   extensions. We use the `patchExtra` argument to specify binaries relative to
   the isaacsim root directory.

   `extraLibs` will be added to LD_LIBRARY_PATH for entrypoints:
    - kit/kit
    - kit/kit-gcov
    - kit/python/python
    - kit/python/python3
    - kit/python/bin/python3
    - kit/python/bin/python3.12

   Things get complicated when the missing extensions are downloaded
   dynamically into the user directory. By design nix derivations can't effect
   those. So it's up to the user to either manually patch them or use a tool
   like [nix-ld](https://github.com/nix-community/nix-ld).

1. Wrapping entry points
   with `LD_LIBRARY_PATH` and `VK_ICD_FILENAMES` for kit and python.

1. Using `realpath`
   to prefix `${BASH_SOURCE}` allows us to run symlinked launch scripts.

1. `x-terminal-emulator`
   used by isaacsim is a debianism and generally not
   available on NixOS. We use a custom argument `terminalCmd` which can be used
   to emulate the command by creating a lightweight wrapper. By default it uses
   the DE-agnostic `xdg-terminal-exec` directly from nixpkgs.

1. Desktop file installation
   via `makeDesktopItem` instead of `post_install.sh`.

1. Adding ros2 extension to `LD_LIBRARY_PATH`
   via `ros.patch`. Previously it didn't work by just setting `ROS_DISTRO`.

## Known issues

- `jupyter_notebook.sh` is **broken**.
  It runs `pip install --upgrade jupyter` against the bundled interpreter
  (`kit/python/bin/python3`) at startup, but that interpreter lives in the
  read-only `/nix/store`, so the install fails and `set -e` aborts the script.
  A fix would need to provide `jupyter` from outside the store (e.g. a devShell
  with `python3Packages.jupyter` plus `source $(which isaacsim-env)`) and
  register the kernelspec manually — untested.

## Useful debugging commands

- Pass `--/app/printConfig=true` to kit to dump configuration.
  It can be used with `--kit_args` with launching with python scripts.

  Sometimes the app definitions overwrite paths to be relative to the isaacsim
  installation directory which doesn't work on nix as the installation location
  is within the read-only /nix/store. Add patches for included extensions.

- `cd $(dirname $(realpath $(which isaacsim)))` to access the nix derivation

