{
  lib,
  stdenv,
  fetchzip,
  # nativeBuildInputs
  makeWrapper,
  addDriverRunpath,
  writeShellScriptBin,
  makeDesktopItem,
  copyDesktopItems,
  # Runtime dependencies
  libGL,
  libGLU,
  libx11,
  libxrandr,
  libxt,
  libxml2_13,
  libbsd,
  # propagatedBuildInputs
  xdg-terminal-exec,
  mpi,
  # Custom args
  terminalCmd ? ''xdg-terminal-exec "$@"'',
  patchExtra ? [],
  extraLibs ? [],
}: let
  pname = "isaacsim";
  version = "5.1.0";
  description = "NVIDIA Isaac Sim™ is a reference application built on NVIDIA Omniverse that enables developers to develop, simulate, and test AI-driven robots in physically-based virtual environments.";

  src = fetchzip {
    name = "isaac-sim-${version}";
    url = "https://downloads.isaacsim.nvidia.com/isaac-sim-standalone-${version}-linux-x86_64.zip";
    sha256 = "sha256-5D+c2/1sOEJcYjxQ2bJb7zeZCCnf4Omv4Qbo3fI5pXY=";
    stripRoot = false;
  };
  patches = [
    ./extscache.patch
    ./ros.patch
  ];

  wrapBins = [
    "kit/kit"
    "kit/kit-gcov"
    "kit/python/python"
    "kit/python/python3"
    "kit/python/bin/python3"
    "kit/python/bin/python3.11"
  ];
  patchBins =
    [
      "exts/isaacsim.ros2.bridge/bin/isaacsim.ros2.bridge.check"
    ]
    ++ patchExtra;
in
  stdenv.mkDerivation {
    inherit pname;
    inherit version;
    inherit src;

    propagatedBuildInputs = [
      xdg-terminal-exec
      mpi
    ];
    nativeBuildInputs = [
      makeWrapper
      addDriverRunpath
      copyDesktopItems
    ];

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    inherit patches;

    postPatch = let
      esc = "\${";
    in
      # bash
      ''
        # Prefix BASH_SOURCE with realpath to make $out/bin symlinks work
        # WARN: brittle approach
        find . -type f -name "*.sh" -print0 | while IFS= read -r -d "" script; do
          substituteInPlace "$script" \
            --replace-quiet 'dirname ${esc}BASH_SOURCE}' 'dirname $(realpath ${esc}BASH_SOURCE})' \
            --replace-quiet '"${esc}BASH_SOURCE[0]}"' '$(realpath "${esc}BASH_SOURCE[0]}")' \
            --replace-quiet '"${esc}BASH_SOURCE[1]}"' '$(realpath "${esc}BASH_SOURCE[1]}")'
        done

        # Don't install .desktop file into `$XDG_DATA_HOME/applications` as we handle
        # installation via `makeDesktopItem`
        substituteInPlace \
          exts/isaacsim.app.setup/isaacsim/app/setup/extension.py \
          --replace-fail "self.__add_app_icon(ext_id)" 'carb.log_warn(f"Skipping isaacsim.desktop installation on NixOS")'
      '';

    installPhase = let
      isaacsimEnv =
        # bash
        ''
          export LD_LIBRARY_PATH="${
            lib.makeLibraryPath (
              [
                stdenv.cc.cc.lib
                addDriverRunpath.driverLink
                libGL
                libGLU
                libx11
                libxrandr
                libxt
                libxml2_13
                libbsd
              ]
              ++ extraLibs
            )
          }:$LD_LIBRARY_PATH"
          export PATH="${
            lib.makeBinPath [(writeShellScriptBin "x-terminal-emulator" "${terminalCmd}")]
          }:$PATH"
          export VK_ICD_FILENAMES="${addDriverRunpath.driverLink}/share/vulkan/icd.d/nvidia_icd.${stdenv.hostPlatform.uname.processor}.json"
          ISAACSIM="${placeholder "out"}/${pname}"
          export ISAAC_PATH="$ISAACSIM"
          export CARB_APP_PATH="$ISAACSIM/kit"
          export EXP_PATH="$ISAACSIM/apps"
          source "$ISAACSIM/setup_python_env.sh"
        '';
    in
      # bash
      ''
        runHook preInstall

        ISAAC="$out/$pname"

        # Binaries
        mkdir -p "$ISAAC"
        mkdir -p "$out/bin"
        mkdir -p $out/share/applications
        cp -r . "$ISAAC"
        ln -s "$ISAAC/isaac-sim.sh" "$out/bin/$pname"
        ln -s "$ISAAC/isaac-sim.selector.sh" "$out/bin/$pname-selector"
        ln -s "$ISAAC/kit/kit" "$out/bin/$pname-kit"
        ln -s "$ISAAC/python.sh" "$out/bin/$pname-python"
        install -Dm755 /dev/stdin "$out/bin/$pname-env" << 'EOF'
          ${isaacsimEnv}
        EOF

        # Emulate post_install.sh
        ln -s $out/$pname/exts/isaacsim.examples.interactive/isaacsim/examples/interactive $out/$pname/extension_examples
        install -Dm644 data/icon/omni.isaac.sim.png $out/share/icons/hicolor/64x64/apps/$pname.png
        runHook postInstall
      '';

    postFixup = ''
      ISAAC="$out/$pname"

      # Patch pre-built binaries
      for exe in ${lib.concatStringsSep " " patchBins}; do
        patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$ISAAC/$exe"
      done

      # Wrap kit and python binaries
      for exe in ${lib.concatStringsSep " " wrapBins}; do
        wrapProgram "$ISAAC/$exe" --run "source $out/bin/isaacsim-env"
      done

      wrapProgram "$ISAAC/python.sh" --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [stdenv.cc.cc.lib]
      }
    '';

    desktopItems = [
      (makeDesktopItem {
        name = pname;
        desktopName = "Isaac Sim";
        comment = description;
        icon = pname;
        terminal = false;
        type = "Application";
        startupWMClass = "IsaacSim";
        exec = "${pname}-selector";
      })
    ];

    meta = {
      inherit description;
      homepage = "https://developer.nvidia.com/isaac-sim";
      downloadPage = "https://docs.isaacsim.omniverse.nvidia.com/${version}/installation/download.html";
      changelog = "https://docs.isaacsim.omniverse.nvidia.com/${version}/overview/release_notes.html";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      license = with lib.licenses; [asl20];
      maintainers = [];
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
