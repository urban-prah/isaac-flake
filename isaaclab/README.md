# Isaac Lab

*WARNING*: This package is broken.

## Issues 
1. Patching `isaaclab.python.kit` to write to /tmp isn't the best idea - non
   persistent cache! Injecting `$HOME` or `os.environ("HOME")` isn't possible
   as kit configuration options are parsed literally. Probably requires a patch in
   one of isaacsim's bundled extensions.

1. If we try packaging isaaclab dependencies as python packages using nix's
   `buildPythonPackage` paths get broken (EXT_PATH set relative to isaaclab
   dir). This can be solved with extensive patching but we suggest the `uv venv`
   approach for now.

## Changes

1. Wrapping `isaaclab.sh`
   to source isaacsim's env and extend `PYTHONPATH` with extra python
   dependencies via `extraPythonLibs` argument.

1. Using `realpath`
   to prefix `${BASH_SOURCE[0]}` allows us to run symlinked launch scripts.


## Working setup with `uv`

We suggest following this steps to use the isaacsim package with isaaclab.

> NOTE: `uv` requires nix-ld to run on NixOS.

1. clone the isaaclab repo
    ```bash
    git clone git@github.com:isaac-sim/IsaacLab.git
    ```
1. let isaaclab know which isaacsim to use
    ```bash
    ln $(dirname $(realpath $(which isaacsim))) _isaac_sim
    ```
1. create and source a python virtual environment
    ```python
    uv venv --python _isaac_sim/python.sh
    source .venv/bin/activate
    ```
1. install isaaclab dependencies
    ```python
    ./isaaclab.sh -i
    ```
1. fix the kit app definition so the paths are outside the nix store replacing paths as needed.
    ```diff
    --- a/apps/isaaclab.python.kit
    +++ b/apps/isaaclab.python.kit
    @@ -282,4 +282,14 @@
     ]
     
    +[settings.app.tokens]
    +data = "/home/<user>/.local/share/isaaclab"
    +cache = "/home/<user>/.local/share/isaaclab/cache"
    +logs = "/home/<user>/.local/share/isaaclab/logs"
    +omni_data = "/home/<user>/.local/share/isaaclab/omni"
    +omni_cache = "/home/<user>/.local/share/isaaclab/omni/cache"
    +omni_logs = "/home/<user>/.local/share/isaaclab/omni/logs"
    +omni_config = "/home/<user>/.local/share/isaaclab/omni/cfg"
    +appcache = "{data}/exts"
    +
     [settings.physics]
     autoPopupSimulationOutputWindow = false

    ```
1. Source isaacsim-env in isaaclab.sh
    ```bash
    grep -q 'isaacsim-env' isaaclab.sh || sed -i '/-p|--python)/a\            source $(which isaacsim-env)' isaaclab.sh"

    ```
1. Run isaaclab app
    ```bash
    ./isaaclab.sh -p scripts/demos/h1_locomotion.py
    ```
