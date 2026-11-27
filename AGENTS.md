# Runtime verification

Before proposing a change or publishing a PR revision:

- Build the affected packages and run `nix flake check`.
- Launch the packaged `isaacsim` application and confirm startup and clean exit.
  Also run `isaacsim/smoke.py` through `isaacsim-python` and confirm simulation
  time advances.
- Run IsaacLab through its packaged launcher. Run `isaaclab/smoke.py` and
  an affected official example through initialization, simulation steps and exit.
- For launcher, runtime-selection or dependency changes, test the official
  example's default backend as well as any documented alternative. A different
  viewer or backend does not establish that the default launch works.
- Record the exact tested commit, commands, exit status, evidence and limitations.
  Builds, import probes and custom smokes do not replace official-example runs.

Run Isaac Sim and IsaacLab instances serially, including across agent threads.
Hold `flock -x "$XDG_RUNTIME_DIR/isaac-runtime-verification.lock"` around each
bounded runtime command. Coordinate existing runs before adopting the lock.
Confirm the previous test process has exited, and check host RAM and GPU memory
headroom. The lock does not cover human-launched apps; do not terminate a user's
simulator to make room for a test.

Keep runtime checks outside the GPU-free flake checks. Bound example runs with
upstream step limits. Use a private test screen when supported; never use the
real desktop without permission. State whether windowed launches were tested.
An unresolved launch failure blocks a claim that runtime verification passed.
