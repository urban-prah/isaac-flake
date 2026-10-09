"""Initialize and locate the persistent writable IsaacLab source workspace."""

import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


SOURCE = Path("@source@")
CP = "@cp@"
CHMOD = "@chmod@"
MARKER = ".nix-isaaclab-source"


def workspace_path():
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    default = data_home / "isaaclab" / "workspaces" / SOURCE.parent.name
    workspace = Path(os.environ.get("ISAACLAB_WORKSPACE", str(default))).expanduser().resolve()
    if workspace.is_relative_to("/nix/store"):
        raise ValueError("ISAACLAB_WORKSPACE must be outside the immutable Nix store")
    return workspace


def initialize_workspace(workspace):
    workspace.parent.mkdir(parents=True, exist_ok=True)
    lock_path = workspace.parent / f".{workspace.name}.lock"
    with lock_path.open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        marker = workspace / MARKER
        if workspace.exists():
            if not marker.is_file() or marker.read_text().strip() != str(SOURCE):
                raise RuntimeError(
                    f"{workspace} is not a workspace for {SOURCE}. "
                    "Select a new ISAACLAB_WORKSPACE; existing files will not be overwritten."
                )
            return
        staging = Path(tempfile.mkdtemp(prefix=f".{workspace.name}-", dir=workspace.parent))
        try:
            subprocess.run([CP, "-a", "--reflink=auto", f"{SOURCE}/.", str(staging)], check=True)
            # Keep executable bits and relative skill aliases. chmod does not
            # traverse the copied _isaac_sim symlink or other child symlinks.
            subprocess.run([CHMOD, "-R", "u+w", str(staging)], check=True)
            (staging / MARKER).write_text(str(SOURCE) + "\n")
            staging.rename(workspace)
        finally:
            if staging.exists():
                shutil.rmtree(staging)


def main():
    workspace = workspace_path()
    initialize_workspace(workspace)
    print(workspace)


if __name__ == "__main__":
    main()
