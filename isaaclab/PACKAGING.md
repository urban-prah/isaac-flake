# IsaacLab uv2nix packaging

The release candidate packages the official `v3.0.0-EA` source and `uv.lock` with
Isaac Sim 6.1.0. Nix fetches declared artifacts and builds dependencies offline.
The launcher uses the simulator's bundled Python without activating a virtualenv.

## Definitions

- `source.nix` installs the complete unpatched source and official agent resources,
  records its revision and links the paired Isaac Sim installation.
- `dependencies.nix` loads upstream `uv.lock` with uv2nix, defines source build
  systems, editable workspace metadata and the required compatibility overrides.
- `environment.nix` composes the selected and consumer dependency graphs with
  `mkVirtualEnv`, installs the startup hook and creates the metadata check.
- `python.nix` wraps Nix's ELF loader around the simulator's Python 3.12 binary
  with explicit native-library paths.
- `workspace.nix` and `runtime/workspace.py` package the source initializer with
  `writers.writePython3Bin` and independently pinned nixpkgs Python.
- `isaaclab.nix` assembles the source, dependencies, interpreter and console
  wrapper with `symlinkJoin` and `makeWrapper`.

The package output exposes `bin/isaaclab`, `bin/isaaclab-workspace`, `isaaclab/`,
`dependencies/`, `venv/` and `python/`. The `venv/` compatibility link names the
build-created environment; it is not activated at runtime. The package's
`source`, `environment`, `python`, `sourceWorkspace` and `workspace` attributes
are available to consumers. `lib.mkIsaacLab` forwards consumer overrides to the
same definition, producing a separate immutable environment.

## Dependency provenance

The official lock supplies core and the `skrl`, `sb3`, `rl-games`, `test`,
`video` and `wandb` extras. Core includes RSL-RL and the Newton viewer. Teleop and
Mimic workspace modules are included for keyboard teleoperation and task
configurations. The complete Mimic and XR/CloudXR extras, OV runtimes and extra
viewer frameworks are not selected. Linux x86_64 uses the locked CUDA 12.8
PyTorch artifacts. Source-only packages retain their locked
sources and receive explicit build backends through `resolveBuildSystem`.

No generated `wheels.json`, wheelhouse or runtime UV installation is involved.
The same pyproject.nix tooling already used by the Isaac Sim MCP package builds
the Python dependencies. Workspace packages use the standard editable hook and
resolve their resources from `$ISAAC_LAB_DIR`. Setuptools builds these editables
with `editable_mode=compat`, so regular upstream packages take precedence over
same-named namespace directories in the caller's working directory. The standard
pyproject.nix editable hook resolves the source root without patching upstream.

Two upstream compatibility corrections remain explicit:

- NumPy 2.3.5 replaces the lock's incompatible 2.5.1 override, satisfying Numba
  and cmeel-boost's `<2.4` constraint. The replacement wheel has a fixed hash.
- Open3D's omitted ipywidgets dependency is selected from the same lock; uv2nix
  follows its transitive graph.

Native wheels receive their declared Python dependencies and nested library
search paths through `autoPatchelf` and `addAutoPatchelfSearchPath`. Targeted
nixpkgs inputs supply cuFile's RDMA libraries, NVSHMEM's MPI/PMIx/UCX/libfabric/RDMA
libraries, Numba's TBB, Open3D's udev and ovstage's hwloc/libXt. Torchaudio and
Open3D need explicit native Torch dependency edges omitted from their metadata.
Only `libcuda.so.1` is deferred to the host driver; other missing libraries fail
builds. The Open3D ML Torch plugin's execution is outside the verified scope.

The dependency check enumerates installed metadata, including Nix-symlinked
distributions, and validates versions, Python/platform markers, requested extras
and the virtual root's requirements. Direct consumer extra selections are included
in that validation. This avoids UV's zero-distribution scan in
this symlink layout. `constraintProjects` supplies additional virtual consumer
manifests that have no installed METADATA. A deliberately incompatible consumer
requirement is rejected; overlays are not an automatic cross-lockfile resolver.

## Runtime boundary

The source initializer copies only the upstream source. `_isaac_sim` remains a
store symlink. A lock serializes first initialization and a temporary sibling
is published atomically. A source marker prevents overwriting an unrelated or
differently versioned directory. Existing edits survive subsequent launches;
a different source derivation receives a separate default workspace.

Python dependencies arrive through `PYTHONPATH`. The startup hook processes
standard `.pth` files, including cmeel and editable metadata. This exposes
Pinocchio's native prefix without requiring a consumer-specific startup hook.
The CLI's virtualenv guard and upstream Python/.kit files are not patched.

The hook delays Kit defaults until SimulationApp starts after user argument
parsing. It supplies writable portable and extension-cache locations while
preserving explicit settings. Its wrapping of a private SimulationApp method is
an existing compatibility workaround that must be reviewed on simulator upgrades.
For Lab experiences it defaults rendering to one GPU unless explicitly configured;
CUDA device visibility stays unchanged. GLFW defaults to X11 and honors an explicit
`PYGLFW_LIBRARY_VARIANT`. Isaac Sim owns Zenity and isolates its native lookup from
bundled ROS/OpenSSL libraries.

## Updating

Change the `isaaclab-src` tag in `flake.nix` and the version in `isaaclab.nix`, then
update only that locked input:

```bash
nix flake update isaaclab-src
nix flake check
nix build .#isaaclab
nix develop --command isaaclab -p isaaclab/smoke.py
```

Review upstream dependency changes and each compatibility override. Verify a
real consumer's simulation, training and existing checkpoint contract, not only
imports. Keep new package files tracked before evaluating a Git-backed flake.
