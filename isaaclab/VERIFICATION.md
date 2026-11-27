# IsaacLab verification

## Release/3.1.0 snapshot, 2026-11-27

IsaacLab source `968fb369b72b5b17d1d1fc7ad17c834d2bc23ef0` was tested with
Isaac Sim 6.2.0 on NixOS x86_64 and an NVIDIA RTX PRO 5000 Blackwell, driver
595.71.05. This is a pre-release branch snapshot, not the final 3.1.0 release.

- `nix build .#isaaclab` passed with NumPy 2.4.6 from a fixed-hash wheel.
  The package uses its existing uv2nix wheel builder, without a nixpkgs adapter.
- `nix flake check --option allow-import-from-derivation false` passed, including
  dependency metadata, consumer extras, workspace integrity and Nix lint.
- The CPU-only fork regression passed 20 runs for each actual BLAS library:
  NumPy 2.4.6 with vendored OpenBLAS 0.3.31.188.0/pthreads, and SciPy 1.18.1
  with vendored OpenBLAS 0.3.31.dev/pthreads. Each run forks from four native threads
  twelve times per thread. Both libraries used four BLAS threads. The same test
  timed out on the previous NumPy wheel's OpenBLAS 0.3.30.
- `nix develop --command isaaclab -p isaaclab/smoke.py` passed without inherited
  OpenBLAS, GOTO or OpenMP thread caps. It checked headless Kit startup and three
  updates, native dependencies, RL imports, writable source/cache paths and CUDA
  matrix multiplication. CuDNN 91900 convolution forward/backward produced finite
  outputs and gradients on the visible GPU.
- A caller-supplied `OPENBLAS_NUM_THREADS=3` survived the packaged launcher,
  and both loaded BLAS libraries reported three threads after matrix operations.

The source remains unpatched. Neither launcher forces a BLAS thread count.
Both NumPy and SciPy now use pthread BLAS and honor `OPENBLAS_NUM_THREADS`.
Numba 0.64 requires NumPy `<2.5`; cmeel-boost 1.90 no longer requires `<2.4`.
The original PR revision retained an obsolete NumPy 2.3.5 constraint and used a
source-build adapter. Its NumPy source-suite results do not apply to this wheel.

Kit startup reports upstream deprecation in 3.1 and removal in 3.2. Existing
`/usr/bin/lscpu`, extension and protobuf warnings remain. These checks do not
verify downstream task APIs, training, checkpoint compatibility, distributed
training or another GPU model. Consumers must re-verify their workflows.

## Official launch verification, 2026-11-27

The initial generic smoke forced Kit and did not test the H1 demo's default
Newton RTX viewer. The official demo reproduced the missing `ovrtx` failure.
The package now selects upstream's `ovrtx` extra, supplies NVIDIA's fixed wheel
instead of its PyPI download stub, and provides hwloc for its native TBB plugin.
Upstream demo and launcher source files remain unpatched.

Live checks of the packaged outputs:

- The `isaacsim` full windowed application reported `Isaac Sim Full App is loaded`
  and `app ready`, then exited with status 0 after a controlled interrupt.
- The separate Isaac Sim scene smoke completed 120 updates and advanced its
  physics timeline by two seconds.
- The official H1 demo initialized its published policy and default Newton
  MuJoCo Warp physics with `OVRTXRenderer`. A headless run bounded to 30 steps
  and a windowed run bounded to 300 steps both exited with status 0.
- The same official H1 demo also passed a five-step headless run with explicit
  `--physics isaacsim_physx --viz kit`.
- The generic IsaacLab Kit/CUDA/CuDNN smoke and full flake checks passed with
  OVRTX selected. The generic smoke records the installed OVRTX version.

The windowed runs had user permission and used the exposed desktop launcher.
Window presence and process results were checked, but the desktop driver could
not capture those windows on the two-output niri session. Viewport appearance
and keyboard interaction were not verified. The H1 run reported unavailable
CUDA/OpenGL interop and used its upstream copy fallback. Existing SDK warnings
remain; the runs do not establish warning-free rendering or performance.

An initial overlapping full-app attempt exceeded its 180-second budget. This is
not counted as a passing test. Runtime tests now use a host-wide `flock` across
agent threads and run serially, with RAM/VRAM headroom checks, as required in
[AGENTS.md](../AGENTS.md).

## Early Access verification, historical

The results below apply only to the Early Access package.

The uv2nix candidate was validated with IsaacLab `v3.0.0-EA`, Isaac Sim 6.1.0 and
an independent consumer project. Python dependencies and the simulator remain
in the Nix store; writable source, caches, assets and test outputs are separate.
Consumer source files and existing checkpoints were preserved during testing.

### Completed release candidate checks

- Standalone and consumer packages built; pure evaluation passed with
  import-from-derivation disabled.
- Installed metadata checks passed for standalone and consumer environments.
  An incompatible `numpy<2` consumer constraint was rejected, including when
  introduced through a directly selected extra. An unselected extra did not
  apply its requirement.
- Concurrent workspace initialization, edit preservation and rejection of unrelated
  directories passed. Upstream Python/.kit files matched the tagged source;
  official agent resources were present.
- Absolute and relative script invocation preserved caller CWD and relative reads,
  including launches from the packaging repository with `PYTHONPATH=.`. Foreign
  virtualenv, Conda and `PYTHONHOME` selections were cleared.
- The core package resolved to its upstream `__init__.py` even beside a same-named
  namespace directory. Teleop, Mimic, Newton and visualizer source modules resolved
  from the selected writable workspace. The namespace regression failed against
  the earlier candidate and passed after selecting the standard editable mode.
- Pinocchio forward kinematics, Pink imports, Numba JIT and Open3D geometry passed.
- Headless Kit updates and skrl, RSL-RL, rl_games and SB3 imports passed through
  the repository's default development shell.
- The official Franka keyboard teleop task initialized with the Kit viewer and
  default camera rendering, completed five finite simulation steps and closed
  cleanly. The temporary test observer only bounded the loop and checked results;
  upstream scripts and task configurations remained unpatched.
- Cartpole completed five finite steps with Newton physics and the Newton GL
  viewer, then closed cleanly. The H1 demo imported with its Kit viewer and ran
  three application updates; its full pretrained-policy playback was not tested.
- Finite PyTorch matrix operations ran on multiple visible CUDA devices.
  Distributed training across GPUs was not tested.
- A consumer simulation evaluation completed without a fall or reset and generated
  its expected JSON artifact. Assets were regenerated from the consumer's URDF.
  The composed package rebuilt and repeated a bounded evaluation after the import
  correction and inclusion of the teleop and Mimic source modules.
- A short skrl training run saved configuration and produced a checkpoint with
  finite policy, value, optimizer and preprocessor tensors. Playback produced
  finite policy outputs with no optimizer updates.
- An existing trained checkpoint retained its observation and action contract
  through consumer configuration. Playback produced finite policy outputs with
  no optimizer updates, and checkpoint hashes remained unchanged. This verifies
  inference compatibility; it does not establish policy performance.
- Consumer-only package metadata stayed absent from standalone IsaacLab and remained
  available after Kit startup. The consumer development-shell interface passed.
- The integrated repository definition repeated the package/native/Kit probes,
  manual smoke, consumer evaluation, training and checkpoint playback checks.
  Its exported `mkIsaacLab` API assembled the tested consumer environment.
- Repository flake checks passed, including dependency and consumer-extra checks,
  concurrent workspace/resource checks, existing MCP smoke and Nix formatting/lint.

### Known limitations

The legacy Gym RecordVideo/rgb_array path produced no video frames. The official
EA `ManagerBasedRLEnv.render()` returns `None` for `rgb_array` and directs
consumers to `VideoRecorderCfg`. Adapting video belongs in the consumer project;
dependency packaging does not change that API behavior.

A fresh camera-enabled launch spent several minutes compiling RTX shaders and
loading scene assets before stepping. Subsequent startup uses the writable cache.
Runtime logs still contain the SDK's hardcoded `/usr/bin/lscpu` lookup and
extension/deprecation warnings. Successful JSON artifacts and finite simulation
steps establish the bounded test result, not the absence of all log noise.

Windowed Kit and Newton launches were verified, but manual keyboard/mouse
interaction was not. The complete XR/CloudXR and Mimic dataset-generation extras
were not selected or tested. No DDS interoperability, full training campaign,
other-framework training, distributed multi-GPU training or Open3D ML Torch plugin
execution was
verified. Graphics drivers, downloaded extensions and remote assets remain runtime
requirements. See [README.md](README.md) for the manual smoke command and
[PACKAGING.md](PACKAGING.md) for the remaining compatibility overrides.
