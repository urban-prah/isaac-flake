{
  pkgs ? import <nixpkgs> {},
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}: rec {
  isaacsim = pkgs.callPackage ./isaacsim/isaacsim.nix {};
  isaacsim-mcp = pkgs.callPackage ./isaacsim/isaacsim-mcp.nix {
    inherit pyproject-nix uv2nix pyproject-build-systems;
  };
  isaacsim-webrtc-streaming-client =
    pkgs.callPackage ./isaacsim/isaacsim-webrtc-streaming-client.nix
    {};
  # WARN: broken
  # isaaclab = pkgs.callPackage ./isaaclab/isaaclab.nix { inherit isaacsim; };
}
