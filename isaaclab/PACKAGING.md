# IsaacLab uv2nix packaging

The package uses a pinned `release/3.1.0` source snapshot and its `uv.lock` with
Isaac Sim 6.2.0. See [README.md](README.md) for the revision and pre-release status.
Nix fetches declared artifacts and builds dependencies offline.
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
`video`, `wandb` and `ovrtx` extras. Core includes RSL-RL and the Newton viewer.
OVRTX supplies the renderer used by the official H1 demo's default Newton RTX
viewer. Teleop and Mimic workspace modules are included for keyboard teleoperation
and task configurations. The complete Mimic and XR/CloudXR extras, OvPhysX runtime
and extra viewer frameworks are not selected. Linux x86_64 uses the locked CUDA 13.0
PyTorch artifacts. Source-only packages retain their locked
sources and receive explicit build backends through `resolveBuildSystem`.

The upstream lock records OVRTX's PyPI download stub, not its binary wheel.
`loadWorkspace` receives that lock with NVIDIA's fixed-hash x86_64 wheel added to
the same package entry. The normal uv2nix wheel builder and native fixups handle
it without executing the network-only stub during a sandboxed build.

No generated `wheels.json`, wheelhouse or runtime UV installation is involved.
The same pyproject.nix tooling already used by the Isaac Sim MCP package builds
the Python dependencies. Workspace packages use the standard editable hook and
resolve their resources from `$ISAAC_LAB_DIR`. Setuptools builds these editables
with `editable_mode=compat`, so regular upstream packages take precedence over
same-named namespace directories in the caller's working directory. The standard
pyproject.nix editable hook resolves the source root without patching upstream.

Two upstream compatibility corrections remain explicit:

- NumPy 2.4.6 replaces the lock's incompatible 2.5.1. Numba 0.64 requires
  `numpy>=1.22,<2.5`; cmeel-boost 1.90 now requires only `numpy>=2.0`, without
  its previous `<2.4` limit. Version 2.4.6 is the latest compatible stable wheel
  as of 2026-11-27, not an exact requirement of IsaacLab. It bundles fixed
  OpenBLAS 0.3.31.188.0. The upstream lock supplies SciPy 1.18.1 with fixed
  OpenBLAS 0.3.31.dev. Both use the existing uv2nix wheel builder and native-wheel
  fixups; no source-build adapter or BLAS thread cap is needed.
- Open3D's omitted ipywidgets dependency is selected from the same lock; uv2nix
  follows its transitive graph.

Native wheels receive their declared Python dependencies and nested library
search paths through `autoPatchelf` and `addAutoPatchelfSearchPath`. Targeted
nixpkgs inputs supply cuFile's RDMA libraries, NVSHMEM's MPI/PMIx/UCX/libfabric/RDMA
libraries, Numba's TBB, Open3D's udev and ovstage's hwloc/libXt. Open3D's bundled
Torch plugin still links the CUDA 12 runtime even though IsaacLab uses CUDA 13.
Torchaudio and Open3D need explicit native Torch dependency edges omitted from
their metadata. CuDNN receives `$ORIGIN` through autoPatchelf's `appendRunpaths`
so its dynamically loaded sibling components resolve without a global library path.
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

Change the `isaaclab-src` ref in `flake.nix` and the version in `isaaclab.nix`, then
update only that locked input:

```bash
nix flake update isaaclab-src
nix flake check
nix build .#isaaclab
nix develop --command isaacsim-python isaacsim/smoke.py
nix develop --command isaaclab -p isaaclab/smoke.py
```

`nix flake check` automatically runs `checks.x86_64-linux.isaaclab-openblas-fork`,
a CPU-only concurrent-native-fork regression for the BLAS libraries loaded by
both NumPy and SciPy, with multiple threads enabled. This is a build-time check,
not an installed command or flake app. Python's GIL serializes `os.fork()`, so it
uses a small native reproducer. The separate manual GPU smoke checks Kit, CuDNN
convolution and its gradients. A passing Kit launch alone cannot rule out the
intermittent native-fork race.

Before proposing a PR revision, also run an affected official IsaacLab example
through initialization, simulation steps and exit. For launcher changes, verify
the example's default backend, not just an alternate viewer. Record headless and
windowed results separately. See [the runtime verification policy](../AGENTS.md).

Review upstream dependency changes and each compatibility override. Verify a
real consumer's simulation, training and existing checkpoint contract, not only
imports. Keep new package files tracked before evaluating a Git-backed flake.
