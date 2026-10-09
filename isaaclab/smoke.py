"""Exercise IsaacLab imports, native dependencies, Kit and visible CUDA devices."""

import argparse
import importlib.metadata
import json
import os
from pathlib import Path
import sys
import tempfile


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, help="Result JSON path (default: a unique file in /tmp)")
args = parser.parse_args()
if args.output is None:
    descriptor, filename = tempfile.mkstemp(prefix="isaaclab-smoke-", suffix=".json", dir="/tmp")
    os.close(descriptor)
    args.output = Path(filename)
args.output = args.output.resolve()
args.output.unlink(missing_ok=True)
# The script owns its flags; Kit receives its own settings from the launcher.
sys.argv = sys.argv[:1]
caller = Path.cwd()

import torch
from isaaclab.app import AppLauncher

application = AppLauncher(headless=True).app
try:
    import carb.tokens
    import isaaclab
    import numba
    import numpy as np
    import open3d
    import pinocchio
    import pink
    from rl_games.common.a2c_common import A2CBase
    from rsl_rl.runners import OnPolicyRunner
    import skrl
    from stable_baselines3 import PPO

    model = pinocchio.buildSampleModelManipulator()
    data = model.createData()
    pinocchio.forwardKinematics(model, data, pinocchio.neutral(model))
    assert np.isfinite(data.oMi[-1].translation).all()
    mesh = open3d.geometry.TriangleMesh.create_box()
    mesh.compute_vertex_normals()
    assert np.isfinite(np.asarray(mesh.vertex_normals)).all()

    @numba.njit
    def compiled_sum(values):
        return values.sum()

    assert compiled_sum(np.arange(5, dtype=np.float64)) == 10
    cuda = []
    for index in range(torch.cuda.device_count()):
        values = torch.ones((4, 4), device=f"cuda:{index}")
        product = values @ values
        assert torch.isfinite(product).all() and torch.all(product == 4)
        torch.cuda.synchronize(index)
        cuda.append({"device": index, "name": torch.cuda.get_device_name(index), "finite_matmul": True})
    assert cuda, "No CUDA devices available"
    workspace = Path(os.environ["ISAAC_LAB_DIR"])
    assert not workspace.is_relative_to("/nix/store")
    assert Path(isaaclab.__file__).resolve().is_relative_to(workspace)
    assert (workspace / "AGENTS.md").is_file()
    assert (workspace / "skills/README.md").is_file()
    cache = carb.tokens.get_tokens_interface().resolve("${cache}")
    assert not cache.startswith("/nix/store/"), cache
    for _ in range(3):
        application.update()
    assert Path.cwd() == caller
    result = {
        "status": "passed",
        "versions": {
            name: importlib.metadata.version(name)
            for name in ["torch", "numpy", "numba", "pin", "pin-pink", "open3d", "newton",
                         "warp-lang", "skrl", "rsl-rl-lib", "stable-baselines3", "rl-games"]
        },
        "cuda": cuda,
        "kit_updates": 3,
        "cache": cache,
        "cwd": str(caller),
        "source_workspace": str(workspace),
        "python": sys.executable,
        "pinocchio_forward_kinematics": "passed",
        "numba_jit": "passed",
        "open3d_geometry": "passed",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result_json = json.dumps(result, indent=2)
    args.output.write_text(result_json + "\n")
    print(result_json, flush=True)
    print(f"ISAACLAB_SMOKE_PASSED: {args.output}", flush=True)
finally:
    application.close()
