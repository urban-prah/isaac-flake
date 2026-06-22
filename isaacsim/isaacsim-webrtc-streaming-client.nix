{
  lib,
  stdenv,
  fetchurl,
  # nativeBuildInputs
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  # Runtime dependencies (Electron / Chromium)
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libgbm,
  libxkbcommon,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  libGL,
  libdrm,
  libsecret,
}: let
  pname = "isaacsim-webrtc-streaming-client";
  version = "2.0.0";
  description = "Isaac Sim WebRTC Streaming Client is a streaming client to view Isaac Sim remotely on your desktop or workstation without a powerful GPU.";

  src = fetchurl {
    name = "${pname}_${version}";
    url = "https://downloads.isaacsim.nvidia.com/isaacsim-webrtc-streaming-client-${version}-linux-x86_64.deb";
    hash = "sha256-AbvTbfe5NhLuDlmcWlCPNlZPxP9PKkNUkx7LJzUTRRM=";
  };
  appDir = "Isaac Sim WebRTC Streaming Client";
  runtimeLibs = [
    libGL
    libdrm
    libsecret
  ];
in
  stdenv.mkDerivation {
    inherit pname version src;
    passthru = {inherit pname version src;};

    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = [
      alsa-lib
      atk
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      glib
      gtk3
      libgbm
      libxkbcommon
      nspr
      nss
      pango
      systemd
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
    ];

    dontConfigure = true;
    dontBuild = true;
    dontWrapGApps = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall

      install -dm755 "$out/opt/${pname}"
      cp -r "opt/${appDir}/." "$out/opt/${pname}"

      cp -r usr/share "$out/share"

      runHook postInstall
    '';

    postFixup = ''
      makeWrapper "$out/opt/${pname}/${pname}" "$out/bin/${pname}" \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"

      substituteInPlace "$out/share/applications/${pname}.desktop" \
        --replace-fail '"/opt/${appDir}/${pname}"' "${pname}"
    '';

    meta = {
      inherit description;
      homepage = "https://docs.isaacsim.omniverse.nvidia.com/${version}/installation/manual_livestream_clients.html";
      downloadPage = "https://docs.isaacsim.omniverse.nvidia.com/${version}/installation/download.html#isaac-sim-latest-release";
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      license = with lib.licenses; [unfree]; # https://docs.isaacsim.omniverse.nvidia.com/6.0.0/common/license-isaac-sim-webrtc-streaming-client.html
      maintainers = [];
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
