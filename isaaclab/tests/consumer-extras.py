"""Verify that a directly selected consumer extra enforces its requirements."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("python", type=Path)
    parser.add_argument("checker", type=Path)
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="isaaclab-extras-check-") as temporary:
        root = Path(temporary)
        metadata = root / "isaaclab_consumer_extras_probe-0.0.0.dist-info"
        metadata.mkdir()
        (metadata / "METADATA").write_text(
            "Metadata-Version: 2.3\n"
            "Name: isaaclab-consumer-extras-probe\n"
            "Version: 0.0.0\n"
            "Provides-Extra: conflict\n"
            'Requires-Dist: numpy<2; extra == "conflict"\n'
        )
        results = {}
        for selected in [False, True]:
            specification = root / "requirements.json"
            specification.write_text(json.dumps({
                "projects": [],
                "dependencies": {"isaaclab-consumer-extras-probe": ["conflict"] if selected else []},
            }))
            process = subprocess.run(
                [args.python, args.checker, "--installed", specification],
                env=dict(os.environ, PYTHONPATH=str(root), PYTHONDONTWRITEBYTECODE="1"),
                text=True, capture_output=True,
            )
            assert process.returncode == int(selected), process.stderr + process.stdout
            result = json.loads(process.stdout)
            if selected:
                assert any("numpy" in failure and "<2" in failure for failure in result["failures"])
            else:
                assert result["status"] == "passed", result
            results["selected" if selected else "unselected"] = result

    print(json.dumps({"status": "passed", "consumer_extra_conflict_rejected": True,
                      "unselected_extra_does_not_apply": True, "cases": results}, indent=2))


if __name__ == "__main__":
    main()
