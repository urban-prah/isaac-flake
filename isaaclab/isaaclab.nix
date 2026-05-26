{
  lib,
  stdenv,
  fetchFromGitHub,
  # nativeBuildInputs
  makeWrapper,
  bash,
  # Runtime dependencies
  isaacsim,
  python311,
  python311Packages,
  # Custom args
  extraPythonLibs ? [],
}: let
  pname = "isaaclab";
  version = "2.3.2";
  description = "Isaac Lab is a unified and modular framework for robot learning that aims to simplify common workflows in robotics research (such as reinforcement learning, learning from demonstrations, and motion planning). It is built on NVIDIA Isaac Sim to leverage the latest simulation capabilities for photo-realistic scenes, and fast and efficient simulation.";

  src = fetchFromGitHub {
    owner = "isaac-sim";
    repo = "IsaacLab";
    rev = "v${version}";
    sha256 = "sha256-amBHUPkyKJ4z7UZkjoypQXj0dd+FITwIdLDH/qSFG3A=";
  };
  patches = [
    ./isaaclab.patch
    ./kit.patch
  ];

  pythonLibs =
    [
      python311Packages.flatdict
      python311Packages.h5py
    ]
    ++ extraPythonLibs;
  extraPythonPath = lib.concatMapStringsSep ":" (pkg: "${pkg}/${python311.sitePackages}") pythonLibs;
in
  stdenv.mkDerivation {
    inherit pname;
    inherit version;
    inherit src;
    inherit patches;

    nativeBuildInputs = [
      makeWrapper
      bash
    ];
    propagatedBuildInputs = [isaacsim];

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      ISAAC="$out/$pname"

      mkdir -p "$ISAAC"
      mkdir -p "$out/bin"
      cp -r . "$ISAAC"

      # Symlink Isaac Sim installation ...
      mkdir -p $out/${pname}/_isaac_sim
      for entry in ${isaacsim}/isaacsim/*; do
        name="$(basename $entry)"
        [[ "$name" == python.sh ]] && continue
        ln -s $entry $out/${pname}/_isaac_sim/$name
      done

      ln -s "$ISAAC/isaaclab.sh" "$out/bin/$pname"
    '';

    postFixup = ''
      wrapProgram "$out/$pname/isaaclab.sh" \
        --run "source $(which isaacsim-env)" \
        --suffix PYTHONPATH : ${
        # WARN: this are not actually installed packages!
        lib.concatMapStringsSep ":" (ext: "${placeholder "out"}/${pname}/source/${ext}") [
          "isaaclab"
          "isaaclab_assets"
          "isaaclab_contrib"
          "isaaclab_mimic"
          "isaaclab_rl"
          "isaaclab_tasks"
        ]
      }:${extraPythonPath}
    '';

    meta = {
      inherit description;
      homepage = "https://isaac-sim.github.io/IsaacLab/v${version}/index.html";
      downloadPage = "https://github.com/isaac-sim/IsaacLab/releases/tag/v${version}";
      changelog = "https://isaac-sim.github.io/IsaacLab/v${version}/source/refs/release_notes.html";
      sourceProvenance = with lib.sourceTypes; [fromSource];
      license = with lib.licenses; [bsd3];
      maintainers = [];
      platforms = ["x86_64-linux"];
      broken = true;
      mainProgram = pname;
    };
  }
