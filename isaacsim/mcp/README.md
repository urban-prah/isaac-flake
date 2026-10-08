# Isaac Sim MCP server

Standalone Nix package for NVIDIA's [Isaac Sim MCP server](https://github.com/NVIDIA-Omniverse/kit-usd-agents/tree/8df4ed105e4202dfb6dff836bd1871bf5eccd308/source/mcp/isaacsim_mcp) 2.2.2, pinned to kit-usd-agents commit `8df4ed105e4202dfb6dff836bd1871bf5eccd308`.

It provides five documentation tools: instructions, extension search, extension details, code example search, and settings search. It runs independently of Isaac Sim, without downloading or starting the simulator. See NVIDIA's [quickstart](https://github.com/NVIDIA-Omniverse/kit-usd-agents/blob/8df4ed105e4202dfb6dff836bd1871bf5eccd308/source/mcp/isaacsim_mcp/README.md) and [architecture documentation](https://github.com/NVIDIA-Omniverse/kit-usd-agents/blob/8df4ed105e4202dfb6dff836bd1871bf5eccd308/source/mcp/isaacsim_mcp/docs/README.md).

## Run

Obtain an API key from [NVIDIA](https://build.nvidia.com/settings/api-keys) and save it in a runtime `.env` file outside the repository:

```dotenv
NVIDIA_API_KEY=your-key
```

Then run from this flake:

```bash
nix run .#isaacsim-mcp -- --env-file /absolute/path/to/isaacsim-mcp.env
```

Alternatively, export `NVIDIA_API_KEY` in the invoking shell. No API key is needed to build the package.

The app defaults to `127.0.0.1:9904`, serving Streamable HTTP at `http://127.0.0.1:9904/mcp`. Configure your MCP client to connect to that URL. `--host`, `--port`, and `--config` override the bind address, port, and installed upstream NAT workflow. `--help` and `--version` work without starting the server. Explicit environment variables take precedence over values loaded with `--env-file`.

The corpus defaults to Isaac Sim **6.1**. The upstream 6.0 corpus is also packaged; select it with `MCP_ISAACSIM_VERSION=6.0`. Search uses NVIDIA's hosted embeddings by default. Hybrid retrieval combines semantic and lexical search; set `OVAI_RERANK=true` to enable optional NVIDIA reranking, or `OVAI_RERANK=false` to disable it. For an existing local NIM deployment, NVIDIA documents `KIT_EMBEDDER_BACKEND=local`, `KIT_LOCAL_EMBEDDER_URL`, `KIT_RERANKER_BACKEND=local`, and `KIT_LOCAL_RERANKER_URL`. The embedding model must match the packaged FAISS indexes. This flake does not deploy NIM models.

Usage logging and NAT's anonymous CLI telemetry default to disabled (`KIT_MCP_DISABLE_USAGE_LOGGING=true` and `NAT_TELEMETRY_ENABLED=false`). Startup therefore does not ask for telemetry consent, including in a fresh interactive shell. Explicit environment variables or values in `--env-file` override these defaults; set `NAT_TELEMETRY_ENABLED=true` to opt in to NAT telemetry, or `KIT_MCP_DISABLE_USAGE_LOGGING=false` to enable usage logging. Redis telemetry retains upstream's opt-in behavior (`TELEMETRY_ENABLED=true`). Credentials and runtime configuration are read at startup and are never embedded in the derivation.

To consume the package from another flake:

```nix
inputs.isaac-flake.packages.${pkgs.stdenv.hostPlatform.system}.isaacsim-mcp
```

## Build and verify

```bash
nix build .#isaacsim-mcp
nix build .#checks.x86_64-linux.isaacsim-mcp-smoke
nix flake check
```

The smoke check loads all six packaged FAISS indexes (6.0 and 6.1), starts the actual HTTP server with fresh HOME/XDG state through both `/dev/null` stdin and an interactive pseudo-terminal, rejects telemetry prompts and plugin-registration tracebacks, negotiates MCP, verifies all five tool names, and calls each tool in both startup modes. Search calls use a local fixture that returns vectors from the packaged indexes, so the check needs no NVIDIA key, GPU, simulator, or external API. This tests protocol, dependency loading, corpus integrity, and retrieval execution; it does not measure semantic search quality or validate a production NVIDIA key.

## Packaging and updates

Python 3.13 and all runtime dependencies are installed in the Nix store using uv2nix. Nothing is installed into a mutable venv at startup. `uv.lock` locks the runtime graph; `pyproject.toml` uses the pinned upstream Poetry lock as resolver constraints, with a documented compatibility correction: OTLP exporters/proto match its OpenTelemetry API/SDK 1.42.1, and protobuf 6.33.6 satisfies both NVIDIA's minimum of 6.33.5 and the modern proto package's `<7` requirement. The upstream lock's 1.11.1 exporters contain generated descriptors incompatible with its protobuf 7.34.1 selection. No plugin is hidden and no pure-Python protobuf fallback is enabled. The original workflow YAML is fetched with the source archive.

`lfs-files.json` contains the path, SHA-256 and size from each Git LFS pointer in the upstream Isaac Sim corpus. Nix fetches these files individually and verifies their hashes, avoiding the unrelated multi-gigabyte corpora in the full kit-usd-agents LFS checkout. Data is installed beside `isaacsim_fns`, as expected upstream; the current retrieval implementation builds missing BM25 indexes in memory and works with the read-only store.

When updating, change the source commit consistently in `isaacsim/isaacsim-mcp.nix` and `pyproject.toml`, refresh the source archive hash and the LFS manifest from that commit, and regenerate the resolver constraints from `source/mcp/isaacsim_mcp/poetry.lock`, preserving or revalidating the documented OpenTelemetry/protobuf correction. Run `GIT_LFS_SKIP_SMUDGE=1 UV_PYTHON_DOWNLOADS=never uv lock --python python3.13` in this directory, then repeat the checks. Keep all NAT modular packages on the same release, as NVIDIA requires.
