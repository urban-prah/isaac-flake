{
  pkgs,
  isaaclab-src,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}: let
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = isaaclab-src;};
  sourcePaths = (pkgs.lib.importTOML "${isaaclab-src}/pyproject.toml").tool.uv.sources;
  lock = pkgs.lib.importTOML "${isaaclab-src}/uv.lock";
  members =
    pkgs.lib.filter (name: name != "isaaclab-dev")
    (builtins.attrNames workspace.deps.default);
  sourceOverrides = final: prev:
    pkgs.lib.genAttrs members (name:
      (prev.${name}.override {
        editableRoot = "$ISAAC_LAB_DIR/${sourcePaths.${name}.path}";
      }).overrideAttrs (old: {
        # Regular package paths take precedence over same-named namespace
        # directories in the caller's CWD, including this repository.
        uvBuildFlags = (old.uvBuildFlags or []) ++ ["--config-setting" "editable_mode=compat"];
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ final.resolveBuildSystem {
            setuptools = [];
            wheel = [];
          };
      }))
    // {
      rl-games = prev.rl-games.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ final.resolveBuildSystem {poetry-core = [];};
      });
      gym = prev.gym.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ final.resolveBuildSystem {
            setuptools = [];
            wheel = [];
          };
      });
      moviepy = prev.moviepy.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ final.resolveBuildSystem {
            setuptools = [];
            wheel = [];
          };
      });
      sphinx-paramlinks = prev.sphinx-paramlinks.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [])
          ++ final.resolveBuildSystem {
            setuptools = [];
            wheel = [];
          };
      });
      # The EA lock overrides NumPy beyond Numba's supported range and
      # cmeel-boost's <2.4 constraint. Match the control package's correction.
      numpy = prev.numpy.overrideAttrs {
        version = "2.3.5";
        src = pkgs.fetchPypi {
          pname = "numpy";
          version = "2.3.5";
          format = "wheel";
          dist = "cp312";
          python = "cp312";
          abi = "cp312";
          platform = "manylinux_2_27_x86_64.manylinux_2_28_x86_64";
          hash = "sha256-DYFj9DrN6ac8KjNgU1Ok8bxHmHRaix1zGDso5bQ1rig=";
        };
      };
    };
  nativeWheelOverrides = final: prev: let
    registryNames =
      pkgs.lib.unique (map (package: package.name)
        (pkgs.lib.filter (package: package.source ? registry) lock.package));
    availableNames = pkgs.lib.filter (name: prev ? ${name}) registryNames;
    systemLibraries = {
      nvidia-cufile-cu12 = [pkgs.rdma-core];
      nvidia-nvshmem-cu12 = [pkgs.openmpi pkgs.pmix pkgs.ucx pkgs.libfabric pkgs.rdma-core];
      numba = [pkgs.tbb];
      open3d = [pkgs.udev];
      ovstage = [pkgs.hwloc pkgs.libxt];
    };
  in
    pkgs.lib.genAttrs availableNames (name:
      if (prev.${name}.format or "") != "wheel"
      then prev.${name}
      else let
        # These wheels ship Torch plugins without declaring their native edge.
        nativeDependencies =
          prev.${name}.dependencies
          // pkgs.lib.optionalAttrs (builtins.elem name ["torchaudio" "open3d"]) {torch = [];};
        nativePythonInputs = final.resolveVirtualEnv nativeDependencies;
      in
        prev.${name}.overrideAttrs (old: {
          # Shared libraries shipped by locked Python dependencies must be
          # visible to autoPatchelf, including the separate CUDA wheel family.
          buildInputs =
            (old.buildInputs or [])
            ++ [pkgs.python312]
            ++ nativePythonInputs
            ++ (systemLibraries.${name} or []);
          # CUDA and cmeel wheels keep native libraries below site-packages,
          # outside autoPatchelf's default $dependency/lib search directory.
          preFixup =
            (old.preFixup or "")
            + pkgs.lib.concatMapStrings (dependency: ''
              if [ -d "${dependency}/${pkgs.python312.sitePackages}" ]; then
                addAutoPatchelfSearchPath "${dependency}/${pkgs.python312.sitePackages}"
              fi
            '')
            nativePythonInputs;
          # The CUDA driver is supplied by the host's graphics-driver closure.
          autoPatchelfIgnoreMissingDeps = ["libcuda.so.1"];
        }));
  pythonBase = pkgs.callPackage pyproject-nix.build.packages {python = pkgs.python312;};
  pythonSet = pythonBase.overrideScope (pkgs.lib.composeManyExtensions [
    pyproject-build-systems.overlays.wheel
    (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
    sourceOverrides
    nativeWheelOverrides
  ]);
  selected = {
    isaaclab-dev = ["skrl" "sb3" "rl-games" "test" "video" "wandb"];
    # Keyboard teleop and task configs need these workspace modules. Select their
    # metadata without the XR extras that also install a second Isaac Sim.
    isaaclab-teleop = [];
    isaaclab-mimic = [];
    # Open3D's wheel imports these despite the EA lock's missing edges.
    ipywidgets = [];
  };
in {
  inherit workspace pythonSet selected;
}
