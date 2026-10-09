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


## Official agent skills

NVIDIA's official `AGENTS.md` and complete `skills/` directory are fetched as
part of the version-pinned Isaac Sim archive and preserved in the installed
derivation. Updating the archive updates these files with the installation;
there is no local skill inventory or copied agent guide to maintain. The package
build checks that the upstream guide and skill catalog are present.

The development shell and `isaacsim-env` expose `ISAAC_SIM_DIR`. Agents working
with this installation should read `$ISAAC_SIM_DIR/AGENTS.md`, then the relevant
skills under `$ISAAC_SIM_DIR/skills/`. The routing catalog is
`$ISAAC_SIM_DIR/skills/SKILLS.md`. Companion files retain their upstream paths.
No global skills, project links, or workspace directories are created. Agents
operating outside the installation must be directed to its guide; exporting an
environment variable alone does not automatically load it in every agent client.

## Runtime verification

Build the package from the repository root:

```bash
nix build .#isaacsim -L
```

Run the headless stage/timeline smoke test through the selected package:

```bash
nix develop --command isaacsim-python isaacsim/smoke.py
```

For manual verification, launch the same lit cube-and-floor scene with a window:

```bash
nix develop --command isaacsim-python isaacsim/smoke.py --gui
```

Pass additional options to the script, for example:

```bash
nix develop --command isaacsim-python isaacsim/smoke.py --gpu 1 --output /tmp/isaacsim-gpu1-smoke.json
```

Each run writes its result to a unique `/tmp/isaacsim-smoke-*.json` file and
prints the path on success. Use `--output PATH` to choose a specific location;
an existing result at that path is removed before startup. Runtime verification
is separate from `nix flake check`, which checks the Nix files.

The default is CUDA GPU 0. Pass `--gpu INDEX` to select another available device.
Both rendering and physics select that GPU, and multi-GPU rendering remains
disabled. Testing individual devices does not verify simultaneous rendering
across multiple GPUs.

Check that the viewport renders the blue cube and floor, that simulation controls
work, and that startup has no fatal Vulkan, library, or extension errors. Close
the window after verification. The result JSON records initialization and 120
application updates; it does not certify visual rendering or numerical physics
parity. Manual verification complements the automated startup check.

## Standalone documentation MCP server

This flake also provides `isaacsim-mcp`, NVIDIA's independent documentation
server. Run `nix run .#isaacsim-mcp -- --env-file /absolute/path/to/server.env`
and connect your MCP client to `http://127.0.0.1:9904/mcp`. It ships the 6.1
documentation corpus and provides five search/reference tools. See
[mcp/README.md](./mcp/README.md) for credentials, local NIM configuration,
package checks, and the scope of its tools.
