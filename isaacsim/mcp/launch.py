"""Launch the official server using the configuration installed by Nix."""

import argparse
import importlib.metadata
import os
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(
        description="NVIDIA Isaac Sim documentation MCP server (Streamable HTTP)."
    )
    parser.add_argument(
        "--version",
        action="version",
        version=importlib.metadata.version("isaacsim-mcp"),
    )
    parser.add_argument(
        "--env-file",
        type=Path,
        help="Load a runtime .env file; existing environment variables take precedence.",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).with_name("config.yaml"),
        help="NAT workflow configuration.",
    )
    parser.add_argument(
        "--host", help="Bind address (MCP_HOST; upstream defaults to 127.0.0.1)."
    )
    parser.add_argument(
        "--port", type=int, help="HTTP port (MCP_PORT; upstream defaults to 9904)."
    )
    args = parser.parse_args()
    if args.env_file:
        if not args.env_file.is_file():
            parser.error(f"Environment file does not exist: {args.env_file}")
        from dotenv import load_dotenv

        load_dotenv(args.env_file, override=False)
    # Apply package defaults after the explicit env file, preserving overrides.
    defaults = {
        "MCP_ISAACSIM_VERSION": "6.1",
        "KIT_MCP_DISABLE_USAGE_LOGGING": "true",
        "NAT_TELEMETRY_ENABLED": "false",
        "OVAI_RERANK_BACKEND": "nvidia",
        "OVAI_RERANK_MODEL": "nvidia/llama-nemotron-rerank-vl-1b-v2",
    }
    for name, value in defaults.items():
        os.environ.setdefault(name, value)
    if not args.config.is_file():
        parser.error(f"Configuration file does not exist: {args.config}")
    if args.host is not None:
        os.environ["MCP_HOST"] = args.host
    if args.port is not None:
        if not 1 <= args.port <= 65535:
            parser.error("Port must be between 1 and 65535.")
        os.environ["MCP_PORT"] = str(args.port)
    sys.argv = ["isaacsim-mcp", str(args.config)]
    from isaacsim_mcp.__main__ import main as upstream_main

    return upstream_main()


if __name__ == "__main__":
    sys.exit(main())
