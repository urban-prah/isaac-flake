{
  lib,
  pkgs,
  callPackage,
  symlinkJoin,
  makeWrapper,
  isaacsim,
  isaaclab-src,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  extraDependencies ? {},
  pythonOverrides ? [],
  constraintProjects ? [],
  name ? "isaaclab-3.0.0-EA",
}: let
  version = "3.0.0-EA";
  tag = "v${version}";
  revision = isaaclab-src.rev;
  source = callPackage ./source.nix {
    inherit version revision isaacsim;
    src = isaaclab-src;
  };
  sourceWorkspace = callPackage ./workspace.nix {inherit source;};
  python = callPackage ./python.nix {inherit isaacsim;};
  dependencies = callPackage ./dependencies.nix {
    inherit pkgs isaaclab-src pyproject-nix uv2nix pyproject-build-systems;
  };
  assembled = callPackage ./environment.nix {
    inherit name isaaclab-src extraDependencies pythonOverrides constraintProjects;
    inherit (dependencies) pythonSet selected;
  };
  inherit (assembled) environment;
in
  symlinkJoin {
    inherit name;
    paths = [source];
    nativeBuildInputs = [makeWrapper];
    postBuild = ''
      mkdir -p "$out/bin"
      ln -s ${environment} "$out/dependencies"
      ln -s ${environment} "$out/venv"
      ln -s ${python} "$out/python"
      ln -s ${lib.getExe sourceWorkspace} "$out/bin/isaaclab-workspace"
      makeWrapper ${python}/bin/python3 "$out/bin/isaaclab" \
        --add-flags ${environment}/bin/isaaclab \
        --unset VIRTUAL_ENV --unset CONDA_PREFIX --unset PYTHONHOME \
        --run 'ISAAC_LAB_DIR="$(${lib.getExe sourceWorkspace})" || exit "$?"; export ISAAC_LAB_DIR' \
        --set ISAAC_SIM_DIR ${isaacsim}/isaacsim \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --set-default PYGLFW_LIBRARY_VARIANT x11 \
        --run 'source ${isaacsim}/bin/isaacsim-env' \
        --prefix PYTHONPATH : ${environment}/lib/python3.12/site-packages
    '';
    passthru = {
      inherit version tag revision source sourceWorkspace python environment;
      workspace = sourceWorkspace;
      kitPython = python;
      inherit (assembled) projectPython dependencySpec constraintSpec;
      tests.dependencies = assembled.check;
    };
    meta = {
      description = "IsaacLab Early Access with an offline uv2nix environment for Isaac Sim";
      homepage = "https://github.com/isaac-sim/IsaacLab/releases/tag/${tag}";
      license = lib.licenses.bsd3;
      platforms = ["x86_64-linux"];
      mainProgram = "isaaclab";
    };
  }
