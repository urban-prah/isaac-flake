{pkgs ? import <nixpkgs> {}}: rec {
  isaacsim = pkgs.callPackage ./isaacsim/isaacsim.nix {};
  # isaaclab = pkgs.callPackage ./isaaclab/isaaclab.nix {inherit isaacsim;};
}
