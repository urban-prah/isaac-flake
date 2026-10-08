"""Exercise the packaged runtime, or show a small scene for manual verification."""

import argparse
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--gui", action="store_true")
parser.add_argument("--gpu", type=int, choices=(0, 1), default=0)
parser.add_argument("--output", type=Path, help="Result JSON path (default: a unique file in /tmp)")
args = parser.parse_args()
if args.output is None:
    fd, output_path = tempfile.mkstemp(prefix="isaacsim-smoke-", suffix=".json", dir="/tmp")
    os.close(fd)
    args.output = Path(output_path)
args.output.unlink(missing_ok=True)
started_at = datetime.now(timezone.utc).isoformat()

from isaacsim import SimulationApp

app = SimulationApp({
    "headless": not args.gui,
    "multi_gpu": False,
    "active_cuda_gpus": [args.gpu],
    "physics_gpu": args.gpu,
    "enable_crashreporter": False,
})

import omni.timeline
import omni.usd
from pxr import Gf, UsdGeom, UsdLux, UsdPhysics

stage = omni.usd.get_context().get_stage()
assert stage is not None, "No USD stage after startup"
UsdGeom.SetStageUpAxis(stage, UsdGeom.Tokens.z)
UsdGeom.SetStageMetersPerUnit(stage, 1.0)
scene = UsdPhysics.Scene.Define(stage, "/World/PhysicsScene")
scene.CreateGravityDirectionAttr(Gf.Vec3f(0, 0, -1))
scene.CreateGravityMagnitudeAttr(9.81)

floor = UsdGeom.Cube.Define(stage, "/World/Floor")
floor.CreateSizeAttr(1.0)
floor.AddScaleOp().Set(Gf.Vec3f(10, 10, 0.1))
floor.AddTranslateOp().Set(Gf.Vec3d(0, 0, -0.05))
UsdPhysics.CollisionAPI.Apply(floor.GetPrim())

cube = UsdGeom.Cube.Define(stage, "/World/Cube")
cube.CreateSizeAttr(0.5)
cube.AddTranslateOp().Set(Gf.Vec3d(0, 0, 2))
cube.CreateDisplayColorAttr([Gf.Vec3f(0.2, 0.5, 0.9)])
UsdPhysics.CollisionAPI.Apply(cube.GetPrim())
UsdPhysics.RigidBodyAPI.Apply(cube.GetPrim())
light = UsdLux.DomeLight.Define(stage, "/World/Light")
light.CreateIntensityAttr(1000)

camera = UsdGeom.Camera.Define(stage, "/World/Camera")
camera.AddTranslateOp().Set(Gf.Vec3d(6, 6, 5))
camera.AddRotateXYZOp().Set(Gf.Vec3f(60, 0, 135))
from omni.kit.viewport.utility import get_active_viewport
viewport = get_active_viewport()
if viewport:
    viewport.set_active_camera(str(camera.GetPath()))

timeline = omni.timeline.get_timeline_interface()
timeline.play()
for _ in range(120):
    app.update()
assert timeline.get_current_time() > 0, "Simulation timeline did not advance"
assert stage.GetPrimAtPath("/World/Cube").IsValid()
install = Path(os.environ["ISAAC_SIM_DIR"])
args.output.parent.mkdir(parents=True, exist_ok=True)
result_json = json.dumps({
    "status": "passed",
    "started_at": started_at,
    "install": str(install),
    "version": (install / "VERSION").read_text().strip(),
    "headless": not args.gui,
    "cuda_gpu": args.gpu,
    "multi_gpu_rendering": False,
    "updates": 120,
    "timeline_seconds": timeline.get_current_time(),
    "stage_prims": ["/World/Cube", "/World/Floor", "/World/Light"],
}, indent=2)
args.output.write_text(result_json + "\n")
print(result_json, flush=True)
print(f"ISAACSIM_SMOKE_PASSED: {args.output}", flush=True)
if args.gui:
    print("Verify the viewport, floor, blue cube, and simulation controls; close the window when done.", flush=True)
    while app.is_running():
        app.update()
app.close()
