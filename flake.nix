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
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages =
          (builtins.attrValues self.packages.${pkgs.stdenv.hostPlatform.system})
          ++ [
            self.formatter.${pkgs.stdenv.hostPlatform.system}
          ];
        shellHook = ''
          ${self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit-check.shellHook}
        '';
      };
    });

    formatter = forAllSystems (
      pkgs: let
        inherit (self.checks.${pkgs.stdenv.hostPlatform.system}.pre-commit-check) config;
        inherit (config) package configFile;
      in
        pkgs.writeShellScriptBin "pre-commit-run" "${pkgs.lib.getExe package} run --all-files --config ${configFile}"
    );

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
