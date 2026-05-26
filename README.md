# NVIDIA Isaac packages for Nix

This is the unofficial Nix flake for NVIDIA Isaac packages.
Official support status can be tracked in [#268](https://github.com/isaac-sim/IsaacSim/discussions/268).

## Packages

- [Isaac Sim 5.1.0](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/index.html) ✅ working
- [Isaac Lab 2.3.2](https://isaac-sim.github.io/IsaacLab/v2.3.2/index.html) ❌ broken (see [README](./isaaclab/README.md))
- [Isaac Sim WbRTC Streaming Client](https://docs.isaacsim.omniverse.nvidia.com/5.1.0/installation/manual_livestream_clients.html) planned 🔜

See [isaacsim/README.md] and [isaaclab/README.md](/isaaclab/README.md) for more info.

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
understating of the architecture and the original source. Some changes,
however, are unavoidable. For those we encourage the use of patches or
substitutions that can't fail silently.

The Nix ecosystem thrives on community contributions — even small fixes like
correcting a dependency, updating a version, or improving documentation make a
difference. Fork the repo, make your changes, and open a pull request.

### LLMs and agents

We have tried to incorporate AI agents to help develop this flake and found the
experience discouraging. The Nix build system complicated and the documentation
can sometimes be hard to find. Attribute paths, dependency declarations, or
patch formats produce opaque errors that are hard to debug without
understanding the surrounding context. Agents tend to make confident but
incorrect changes that look plausible on review.

As a result we are reluctant to accept AI-generated contributions and prefer
changes written and reviewed by people familiar with Nix and the NVIDIA Isaac
ecosystem.
