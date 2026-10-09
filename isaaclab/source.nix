{
  lib,
  stdenvNoCC,
  src,
  version,
  revision,
  isaacsim,
}:
stdenvNoCC.mkDerivation {
  pname = "isaaclab-source";
  inherit version src;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/isaaclab"
    cp -a . "$out/isaaclab/"
    ln -s ${isaacsim}/isaacsim "$out/isaaclab/_isaac_sim"
    printf '%s\n' ${lib.escapeShellArg revision} > "$out/isaaclab/.source-revision"
    test -f "$out/isaaclab/AGENTS.md"
    test -f "$out/isaaclab/skills/README.md"
    runHook postInstall
  '';
}
