# IsaacLab

The default IsaacLab packaging approach is a uv2nix release candidate for NVIDIA's
`v3.0.0-EA` tag, paired with Isaac Sim 6.1.0. The source input is locked to
`ae37b028ea415c91ea2bc32609efcd759ed2b974`. This is Early Access, rather than the
moving `release/3.0.0` branch.

Upstream `uv.lock` supplies Python dependencies and fixed artifacts. Nix builds
an immutable dependency environment; there is no maintained wheel manifest or
runtime installer. The full upstream source and official agent resources are
stored in the derivation and copied automatically into a persistent writable
workspace. See [PACKAGING.md](PACKAGING.md) for the dependency and runtime design,
and [VERIFICATION.md](VERIFICATION.md) for the tested scope and limitations.

## Build and run

```bash
nix build .#isaaclab
result/bin/isaaclab --help
result/bin/isaaclab -p /absolute/path/to/your_script.py
result/bin/isaaclab -p ./relative/path/to/your_script.py

nix develop --command isaaclab --help
nix develop --command isaaclab -p isaaclab/smoke.py
```

The smoke test prints JSON and writes a unique result file in `/tmp` by default.
It needs the NVIDIA driver and exercises Kit startup, native dependencies,
framework imports and each visible CUDA device. It is a manual runtime check;
`nix flake check` does not start the simulator or require a GPU.

`isaaclab` invokes the official Python console CLI with Isaac Sim's bundled
Python 3.12. It exports `ISAAC_LAB_DIR` and `ISAAC_SIM_DIR`, clears external
virtual/Conda environment selection and preserves the caller's working directory.
Relative files opened by an absolute-path script still resolve from that directory
unless the script explicitly chooses another location. `isaaclab.sh` and
`isaaclab -i` are not needed for this packaged runtime.

## Teleoperation and viewers

Keyboard teleoperation needs an explicit task. For example:

```bash
nix develop --command isaaclab teleop run \
  --task IsaacContrib-Stack-Cube-Franka-IK-Rel \
  --viz kit --num_envs 1 --teleop_device keyboard
```

The default environment includes the upstream teleop and Mimic source modules
needed by that entry point and task configurations. The complete XR/CloudXR and
Mimic dataset-generation dependency extras are not selected or verified.

A viewer flag does not convert a demo to another backend. The H1 locomotion demo
uses Kit viewport and input APIs and restricts physics to PhysX; retain its Kit
viewer:

```bash
cd "$(isaaclab-workspace)"
isaaclab -p scripts/demos/h1_locomotion.py --viz kit
```

Newton-compatible scripts can select `--viz newton` (the Newton GL viewer).
For example, a bounded Cartpole run can select Newton physics explicitly:

```bash
cd "$(isaaclab-workspace)"
isaaclab -p scripts/environments/zero_agent.py \
  --task Isaac-Cartpole-Direct --num_envs 1 --max_steps 300 \
  --viz newton physics=newton_mjwarp
```

## Writable source and runtime state

`ISAAC_LAB_DIR` names a persistent source workspace, initialized automatically at:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/isaaclab/workspaces/<source-derivation-name>
```

Set `ISAACLAB_WORKSPACE` to choose an exact alternative directory.
`isaaclab-workspace` initializes and prints the active path. Initialization is
locked and atomic, preserves existing edits, and rejects directories belonging
to another source identity. Only source is copied: Isaac Sim, Python and Python
dependencies remain in the Nix store. The upstream Python and `.kit` files stay
unpatched. The installed `AGENTS.md`, `skills/` and relative provider aliases are
available in both the derivation's `isaaclab/` tree and the writable workspace.

Kit configuration and logs default to
`${XDG_DATA_HOME:-$HOME/.local/share}/isaaclab`; extension caches default to
`${XDG_DATA_HOME:-$HOME/.local/share}/isaacsim/extscache`. The respective overrides
are `ISAACLAB_PORTABLE_ROOT` and `ISAACSIM_EXTSCACHE`.

Source-relative outputs land in the writable workspace. Caller-relative outputs,
including `.pretrained_checkpoints` and training logs, retain upstream behavior.
Run upstream demos from the workspace to keep these outputs outside a repository:

```bash
cd "$(isaaclab-workspace)"
isaaclab -p scripts/demos/sensors/cameras.py --headless
```

An explicit script path into `/nix/store` still names an immutable file. Use the
workspace path for examples that write beside their own script. Project scripts
normally run from their project directory, preserving relative assets and logs.

## Consumer dependencies

The flake exports `lib.mkIsaacLab` to compose a project-specific environment:

```nix
projectIsaacLab = inputs.isaac-flake.lib.mkIsaacLab {
  inherit system;
  name = "my-project-isaaclab";
  pythonOverrides = [projectPythonOverlay];
  extraDependencies = { my-project = []; };
  constraintProjects = [{ manifest = ./pyproject.toml; extras = []; }];
};
```

`projectPythonOverlay` is a normal pyproject.nix overlay defining the project's
packages and dependencies. It may compose a consumer uv2nix overlay. The package
factory also accepts its arguments through `packages.${system}.isaaclab.override`.
Put `projectIsaacLab` in the consumer's development shell and provide any source
path required by its editable package. The consumer owns its package metadata,
editable source and any environment variables needed to locate that source.

Project dependencies belong in the consumer. Pinocchio's `pin` and `pin-pink`
belong in the base because the official IsaacLab tag requires them. Packages built
for other Python versions belong in their matching environments; they cannot be
added to this Python 3.12 environment. Overlays compose package sets; they do not
reconcile conflicting versions automatically. Run the composed package's
`tests.dependencies` check and its real project workflow before accepting a new
dependency combination.
