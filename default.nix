{pkgs ? import <nixpkgs> {}}: rec {
  isaacsim = pkgs.callPackage ./isaacsim/isaacsim.nix {};
  isaacsim-webrtc-streaming-client =
    pkgs.callPackage ./isaacsim/isaacsim-webrtc-streaming-client.nix
    {};
  # WARN: broken
  # isaaclab = pkgs.callPackage ./isaaclab/isaaclab.nix { inherit isaacsim; };
}
