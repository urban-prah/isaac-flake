# Release candidate verification

The uv2nix candidate was validated with IsaacLab `v3.0.0-EA`, Isaac Sim 6.1.0 and
an independent consumer project. Python dependencies and the simulator remain
in the Nix store; writable source, caches, assets and test outputs are separate.
Consumer source files and existing checkpoints were preserved during testing.

## Completed release candidate checks

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

## Known limitations

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
