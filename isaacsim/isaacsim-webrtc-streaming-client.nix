{
  lib,
  fetchurl,
  # nativeBuildInputs
  appimageTools,
  lndir,
  makeDesktopItem,
  copyDesktopItems,
}: let
  pname = "isaacsim-webrtc-streaming-client";
  version = "1.1.5";
  description = "Isaac Sim WebRTC Streaming Client is a streaming client to view Isaac Sim remotely on your desktop or workstation without a powerful GPU.";

  src = fetchurl {
    name = "${pname}_${version}";
    url = "https://downloads.isaacsim.nvidia.com/isaacsim-webrtc-streaming-client-${version}-linux-x64.AppImage";
    sha256 = "sha256-908jtpi0YJblD8rm4uR3TPz/cZxD3fbxbtbfnnDQkg4=";
  };
  extracted = appimageTools.extractType2 {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;
    passthru = {inherit pname version src;};

    nativeBuildInputs = [copyDesktopItems];

    extraInstallCommands =
      # bash
      ''
        mkdir -p $out/share
        "${lndir}/bin/lndir" -silent "${extracted}/usr/share" "$out/share"
        mkdir $out/share/applications
      '';

    desktopItems = [
      (makeDesktopItem {
        name = pname;
        desktopName = "Isaac Sim WebRTC Streaming Client";
        comment = description;
        icon = pname;
        terminal = false;
        type = "Application";
        startupWMClass = "IsaacSim";
        exec = "${pname}";
      })
    ];

    meta = {
      inherit description;
      homepage = "https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/manual_livestream_clients.html";
      downloadPage = "https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/download.html#isaac-sim-latest-release";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      license = with lib.licenses; [unfree]; # https://docs.isaacsim.omniverse.nvidia.com/5.1.0/common/license-isaac-sim-webrtc-streaming-client.html
      maintainers = [];
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
