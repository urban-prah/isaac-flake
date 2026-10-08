# NVIDIA Isaac packages for Nix

This is the unofficial Nix flake for NVIDIA Isaac packages.
Official support status can be tracked in [#268](https://github.com/isaac-sim/IsaacSim/discussions/268).

## Packages

- [Isaac Sim 6.1.0](https://docs.isaacsim.omniverse.nvidia.com/6.1.0/index.html) ✅ working
- [Isaac Sim MCP](./isaacsim/mcp/README.md) — ✅ working
- [Isaac Lab 2.3.2](https://isaac-sim.github.io/IsaacLab/v2.3.2/index.html) ❌ broken (see [README](./isaaclab/README.md))
- [Isaac Sim WebRTC Streaming Client](https://docs.isaacsim.omniverse.nvidia.com/6.0.1/installation/manual_livestream_clients.html) ✅ working

See [isaacsim/README.md](/isaacsim/README.md) and [isaaclab/README.md](/isaaclab/README.md) for more info.

Other Isaac Sim versions are available on separate git branches named after the
Isaac Sim version they package (e.g. the `v5.1.0` branch packages Isaac Sim
5.1.0). The `main` branch always tracks the latest **stable** version.

> Note that the isaacsim-selector has been removed in v6.0.0 and with it the
> default flake entry-point has also been changed to just `isaacsim`

## Usage

Use in a flake-based project by adding this flake as an input:

```nix
{
  inputs.isaac-flake.url = "github:urban-prah/isaac-flake";
}
```

Then reference the packages:

```nix
{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.isaac-flake.packages.${pkgs.stdenv.hostPlatform.system}.isaacsim
  ];
}
```

You can also run Isaac Sim directly with:
```bash
nix run github:urban-prah/isaac-flake#isaacsim
```

## Known issues & limitations

- **Dynamic extension downloads**: Extensions downloaded at runtime into the
  user directory are not patched for Nix. Use [nix-ld](https://github.com/nix-community/nix-ld) or patch them manually.

- We haven't yet tested on platforms outside NixOS. It technically should work with [NixGL](https://github.com/nix-community/nixgl).

- **NVIDIA driver version**: Follow the version-specific
  [NVIDIA requirements](https://docs.isaacsim.omniverse.nvidia.com/6.1.0/installation/requirements.html).
  NVIDIA lists Linux 595.58.03 as its tested x86_64 driver for 6.1.0.
- **x86_64 only**: Only `x86_64-linux` is supported for now.

- Apps/scripts which try to pip install dependencies won't work (like
  jupyter-notebook.sh). Current workaround is to use virtual environments.

- **Overridden app paths**: `isaaclab.python.kit` requires modifications to
  redirect certain paths to point outside the /nix/store (see [README](./isaaclab/README.md))

## Contributing

Pull requests are welcome. If you use this flake or run into issues, consider
improving the Nix package definitions and submitting a PR. Specifically:

- Fix broken or incomplete package definitions (e.g. Isaac Lab)
- Add missing flags or overrides
- Improve patch files for upstream compatibility
- Add support for additional platforms (`aarch64`, etc.)
- Document workarounds and known issues

The goal of this project is to eventually get our packages into nixpkgs or
serve as a starting point for official NVIDIA support.

### Philosophy

We want to make as little changes to the source as possible. With tricks like
```nix
export PATH="${
  lib.makeBinPath [ (writeShellScriptBin "x-terminal-emulator" "${terminalCmd}") ]
}:$PATH"
```
we can adapt to the expectations of the original software. This makes the
package easier to maintain and update. It also doesn't require deep
understanding of the architecture and the original source. Some changes,
however, are unavoidable. For those we encourage the use of patches or
substitutions that can't fail silently.

The Nix ecosystem thrives on community contributions — even small fixes like
correcting a dependency, updating a version, or improving documentation make a
difference. Fork the repo, make your changes, and open a pull request.
