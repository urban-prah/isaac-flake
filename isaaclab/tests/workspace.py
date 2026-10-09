"""Check workspace ownership, source integrity and caller-independent imports."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import filecmp
import json
import os
from pathlib import Path
import subprocess
import tempfile


_IMPORT_PROBE = """
import importlib.util
import json
import os
from pathlib import Path
import isaaclab
from isaaclab import _deprioritize_prebundle_paths
root = Path(os.environ["ISAAC_LAB_DIR"])
assert Path(isaaclab.__file__).resolve() == root / "source/isaaclab/isaaclab/__init__.py"
assert callable(_deprioritize_prebundle_paths)
origins = {}
for name in ("isaaclab_teleop", "isaaclab_mimic", "isaaclab_newton", "isaaclab_visualizers"):
    spec = importlib.util.find_spec(name)
    assert spec is not None and spec.origin is not None, name
    origin = Path(spec.origin).resolve()
    assert origin.is_relative_to(root / "source"), (name, origin)
    origins[name] = str(origin)
print(json.dumps(origins))
"""


def check_package_imports(package, workspace, caller):
    """Resolve real upstream packages despite a same-named caller directory."""
    caller.mkdir()
    (caller / "isaaclab").mkdir()
    environment = dict(os.environ, ISAAC_LAB_DIR=str(workspace))
    for pythonpath in ("", "."):
        imported = subprocess.run(
            [package / "venv/bin/python", "-c", _IMPORT_PROBE], cwd=caller,
            env=dict(environment, PYTHONPATH=pythonpath),
            text=True, capture_output=True,
        )
        assert imported.returncode == 0, imported.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("upstream", type=Path)
    args = parser.parse_args()
    helper = args.package / "bin/isaaclab-workspace"

    with tempfile.TemporaryDirectory(prefix="isaaclab-workspace-check-") as temporary:
        root = Path(temporary)
        workspace = root / "workspace"
        environment = dict(os.environ, ISAACLAB_WORKSPACE=str(workspace))

        def initialize():
            return subprocess.check_output([helper], env=environment, text=True).strip()

        with ThreadPoolExecutor(max_workers=4) as executor:
            paths = list(executor.map(lambda _: initialize(), range(4)))
        assert paths == [str(workspace)] * 4, paths
        assert (workspace / ".nix-isaaclab-source").is_file()
        assert (workspace / "_isaac_sim").is_symlink()
        assert (workspace / "_isaac_sim").resolve().is_relative_to("/nix/store")
        sentinel = workspace / "preserve-edits.txt"
        sentinel.write_text("preserve user edits\n")
        assert initialize() == str(workspace)
        assert sentinel.read_text() == "preserve user edits\n"

        resources = [
            path for path in args.upstream.rglob("*")
            if path.is_file() and path.suffix in (".py", ".kit")
        ]
        assert resources
        for path in resources:
            relative = path.relative_to(args.upstream)
            assert filecmp.cmp(path, workspace / relative, shallow=False), relative
        assert (workspace / "AGENTS.md").is_file()
        assert (workspace / "skills/README.md").is_file()

        check_package_imports(args.package, workspace, root / "caller")

        unrelated = root / "unrelated"
        unrelated.mkdir()
        (unrelated / "keep.txt").write_text("existing unrelated directory\n")
        rejected = subprocess.run(
            [helper], env=dict(environment, ISAACLAB_WORKSPACE=str(unrelated)),
            text=True, capture_output=True,
        )
        assert rejected.returncode != 0
        assert "existing files will not be overwritten" in rejected.stderr
        assert (unrelated / "keep.txt").read_text() == "existing unrelated directory\n"

    print(json.dumps({
        "status": "passed",
        "concurrent_initializations": 4,
        "reuse_preserves_edits": True,
        "core_import_ignores_caller_namespace": True,
        "explicit_caller_pythonpath_preserved": True,
        "teleop_mimic_newton_and_visualizer_sources_importable": True,
        "unrelated_directory_rejected": True,
        "unpatched_python_and_kit_files": len(resources),
        "simulator_is_store_symlink": True,
        "official_agents_and_skills_present": True,
    }, indent=2))


if __name__ == "__main__":
    main()
