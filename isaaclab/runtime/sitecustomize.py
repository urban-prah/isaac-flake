"""Supply writable Kit defaults for the immutable IsaacLab installation.

Kit launch sources stay unchanged. This hook delays Kit configuration until
Isaac Sim's SimulationApp module loads.
Explicit --portable-root and --ext-folder arguments retain precedence.
"""
import importlib.abc
import importlib.machinery
import os
from pathlib import Path
import site
import sys

# Process wheel and editable .pth files when dependencies arrive via PYTHONPATH.
site.addsitedir(str(Path(__file__).parent))

_TARGETS = {"isaacsim.simulation_app.simulation_app", "simulation_app.simulation_app"}


def _configure(module):
    app_class = module.SimulationApp
    original_start = app_class._start_app
    original_init = app_class.__init__

    def initialize(self, launch_config=None, experience=""):
        # Preserve an explicit launcher configuration as well as Kit argv.
        self._isaaclab_explicit_multi_gpu = launch_config is not None and "multi_gpu" in launch_config
        return original_init(self, launch_config, experience)

    def start_with_writable_defaults(self):
        original_argv = sys.argv
        arguments = list(original_argv)
        data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        supplied = arguments + list(self.config.get("extra_args", []))
        portable_root = Path(os.environ.get("ISAACLAB_PORTABLE_ROOT", str(data_home / "isaaclab")))
        extension_cache = Path(os.environ.get("ISAACSIM_EXTSCACHE", str(data_home / "isaacsim/extscache")))
        if not any(argument.partition("=")[0] == "--portable-root" for argument in supplied):
            portable_root.mkdir(parents=True, exist_ok=True)
            arguments.extend(["--portable-root", str(portable_root)])
        if not any(argument.partition("=")[0] == "--ext-folder" for argument in supplied):
            extension_cache.mkdir(parents=True, exist_ok=True)
            arguments.extend(["--ext-folder", str(extension_cache)])
        gpu_setting = "--/renderer/multiGpu/enabled"
        experience = Path(self.config.get("experience", "")).name
        if (experience.startswith("isaaclab.")
                and not self._isaaclab_explicit_multi_gpu
                and not any(argument.partition("=")[0] == gpu_setting for argument in supplied)):
            # SimulationApp's True default otherwise overrides Lab's official
            # single-renderer .kit policy, which stalls this heterogeneous host.
            arguments.append(gpu_setting + "=false")
        # SimulationApp determines portable mode from argv after the user
        # script has parsed its flags; inserting here avoids changing its CLI.
        sys.argv = arguments
        try:
            return original_start(self)
        finally:
            sys.argv = original_argv

    app_class.__init__ = initialize
    app_class._start_app = start_with_writable_defaults


class _Loader(importlib.abc.Loader):
    def __init__(self, original):
        self.original = original

    def create_module(self, spec):
        return self.original.create_module(spec)

    def exec_module(self, module):
        self.original.exec_module(module)
        _configure(module)


class _Finder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname, path=None, target=None):
        if fullname not in _TARGETS:
            return None
        spec = importlib.machinery.PathFinder.find_spec(fullname, path)
        if spec is not None and spec.loader is not None:
            spec.loader = _Loader(spec.loader)
            sys.meta_path.remove(self)
        return spec


sys.meta_path.insert(0, _Finder())
