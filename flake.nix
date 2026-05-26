{
  description = "Isaac Nix packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs = {
    self,
    nixpkgs,
    git-hooks,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});

    packages = forAllSystems (pkgs: import ./default.nix {inherit pkgs;});
  in {
    inherit packages;
    formatter = forAllSystems (pkgs: pkgs.alejandra);
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = builtins.attrValues packages.${pkgs.stdenv.hostPlatform.system};
        shellHook = ''
          ${self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit-check.shellHook}
        '';
      };
    });

    checks = forAllSystems (pkgs: {
      pre-commit-check = git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run {
        src = ./.;
        package = pkgs.prek;
        hooks = {
          alejandra.enable = true;
          deadnix.enable = true;
          statix.enable = true;
        };
      };
    });
  };
}
