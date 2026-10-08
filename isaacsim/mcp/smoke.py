"""Offline package check: real MCP protocol and corpus, fixture embeddings."""

import asyncio
from contextlib import contextmanager
import errno
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import pty
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

import faiss
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client
import isaacsim_fns


TOOLS = {
    "get_isaac_sim_instructions",
    "search_isaac_sim_extensions",
    "get_isaac_sim_extension_details",
    "search_isaac_sim_code_examples",
    "search_isaac_sim_settings",
}


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def index_fixtures():
    data = Path(isaacsim_fns.__file__).parent / "data"
    stats = {}
    vectors = {}
    for index_path in sorted(data.rglob("index.faiss")):
        index = faiss.read_index(str(index_path))
        assert index.ntotal > 0, f"Empty index: {index_path}"
        metadata = json.loads(index_path.with_name("index.json").read_text())
        assert metadata["format_version"] == 1
        assert len(metadata["index_to_docstore_id"]) == index.ntotal
        stats[str(index_path.relative_to(data))] = {
            "vectors": index.ntotal,
            "dimensions": index.d,
        }
        if "6.1" in index_path.parts:
            kind = (
                "settings"
                if "settings" in index_path.parts
                else "code"
                if "code_examples" in index_path.parts
                else "extensions"
            )
            vectors[kind] = index.reconstruct(0).tolist()
    assert len(stats) == 6 and set(vectors) == {"extensions", "code", "settings"}, stats
    return stats, vectors


async def check_tools(port):
    async with streamable_http_client(f"http://127.0.0.1:{port}/mcp") as (
        read,
        write,
        _,
    ):
        async with ClientSession(read, write) as session:
            initialized = await session.initialize()
            names = {tool.name for tool in (await session.list_tools()).tools}
            assert names == TOOLS, names
            calls = [
                (
                    "get_isaac_sim_instructions",
                    {"instruction_sets": "robot_setup"},
                    "robot",
                ),
                (
                    "get_isaac_sim_extension_details",
                    {"extension_ids": "isaacsim.sensors.camera"},
                    "camera",
                ),
                (
                    "search_isaac_sim_extensions",
                    {"query": "nix smoke extensions"},
                    None,
                ),
                ("search_isaac_sim_code_examples", {"query": "nix smoke code"}, None),
                ("search_isaac_sim_settings", {"query": "nix smoke settings"}, None),
            ]
            results = {}
            for name, arguments, expected in calls:
                response = await session.call_tool(name, arguments)
                content = "\n".join(
                    item.text for item in response.content if item.type == "text"
                )
                assert not response.isError, content
                assert (
                    content
                    and "ERROR:" not in content
                    and "No relevant documentation found" not in content
                ), content
                if expected:
                    assert expected in content.lower(), content[:1000]
                results[name] = {"characters": len(content), "ok": True}
            return {"server": initialized.serverInfo.model_dump(), "tools": results}


STARTUP_FAILURES = (
    "Allow anonymous telemetry?",
    "NeMo Agent Toolkit — anonymous telemetry",
    "An error occurred while loading plugin",
    "Descriptors cannot be created directly",
    "Traceback (most recent call last)",
)


def assert_clean_startup(log_path):
    text = log_path.read_text()
    for failure in STARTUP_FAILURES:
        assert failure not in text, f"Unexpected startup output: {failure}\n{text}"


@contextmanager
def running_server(command, env, cwd, log_path, interactive):
    master = slave = None
    reader = None
    with log_path.open("w") as log:
        if interactive:
            master, slave = pty.openpty()
            streams = {"stdin": slave, "stdout": slave, "stderr": slave}
        else:
            streams = {
                "stdin": subprocess.DEVNULL,
                "stdout": log,
                "stderr": subprocess.STDOUT,
            }
        server = subprocess.Popen(
            command, env=env, cwd=cwd, start_new_session=True, **streams
        )
        if interactive:
            os.close(slave)
            slave = None

            def drain():
                while True:
                    try:
                        chunk = os.read(master, 65536)
                    except OSError as error:
                        if error.errno == errno.EIO:
                            return
                        raise
                    if not chunk:
                        return
                    log.write(chunk.decode(errors="replace"))
                    log.flush()

            reader = threading.Thread(target=drain, daemon=True)
            reader.start()
        try:
            yield server
        finally:
            if server.poll() is None:
                os.killpg(server.pid, signal.SIGTERM)
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(server.pid, signal.SIGKILL)
                    server.wait()
            if reader:
                reader.join(timeout=5)
                os.close(master)
            if slave is not None:
                os.close(slave)


def main():
    stats, vectors = index_fixtures()
    requests_seen = []

    class EmbeddingFixture(BaseHTTPRequestHandler):
        def do_POST(self):
            assert self.path == "/v1/embeddings", self.path
            payload = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            inputs = payload["input"]
            if isinstance(inputs, str):
                inputs = [inputs]
            records = []
            for i, text in enumerate(inputs):
                kind = (
                    "settings"
                    if "settings" in text
                    else "code"
                    if "code" in text
                    else "extensions"
                )
                requests_seen.append(kind)
                records.append({"index": i, "embedding": vectors[kind]})
            body = json.dumps({"data": records}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    fixture = ThreadingHTTPServer(("127.0.0.1", 0), EmbeddingFixture)
    thread = threading.Thread(target=fixture.serve_forever, daemon=True)
    thread.start()
    runs = {}
    try:
        for interactive in (False, True):
            requests_seen.clear()
            port = free_port()
            mode = "interactive_pty" if interactive else "stdin_devnull"
            with tempfile.TemporaryDirectory(prefix="isaacsim-mcp-smoke-") as tmp:
                log_path = Path(tmp) / "server.log"
                env = os.environ.copy()
                # Exercise launcher defaults, independent of caller consent/cache state.
                for name in (
                    "NAT_TELEMETRY_ENABLED",
                    "KIT_MCP_DISABLE_USAGE_LOGGING",
                    "PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION",
                ):
                    env.pop(name, None)
                env.update(
                    {
                        "NVIDIA_API_KEY": "nvapi-offline-package-check",
                        "KIT_EMBEDDER_BACKEND": "local",
                        "KIT_LOCAL_EMBEDDER_URL": f"http://127.0.0.1:{fixture.server_port}",
                        "MCP_ISAACSIM_VERSION": "6.1",
                        "OVAI_RERANK": "false",
                        "TELEMETRY_ENABLED": "false",
                        "HOME": tmp,
                        "XDG_CONFIG_HOME": str(Path(tmp) / "config"),
                        "XDG_CACHE_HOME": str(Path(tmp) / "cache"),
                        "XDG_DATA_HOME": str(Path(tmp) / "data"),
                        "XDG_STATE_HOME": str(Path(tmp) / "state"),
                    }
                )
                try:
                    with running_server(
                        [sys.argv[1], "--port", str(port)],
                        env,
                        tmp,
                        log_path,
                        interactive,
                    ) as server:
                        deadline = time.monotonic() + 90
                        while True:
                            assert_clean_startup(log_path)
                            if server.poll() is not None:
                                raise RuntimeError(
                                    f"Server exited with status {server.returncode}"
                                )
                            try:
                                with socket.create_connection(
                                    ("127.0.0.1", port), timeout=0.2
                                ):
                                    break
                            except OSError:
                                if time.monotonic() >= deadline:
                                    raise TimeoutError(
                                        "MCP server did not listen within 90 seconds"
                                    )
                                time.sleep(0.2)
                        result = asyncio.run(
                            asyncio.wait_for(check_tools(port), timeout=90)
                        )
                        assert set(requests_seen) == {
                            "extensions",
                            "code",
                            "settings",
                        }, requests_seen
                    assert_clean_startup(log_path)
                    result["startup_clean"] = True
                    runs[mode] = result
                except BaseException:
                    print(log_path.read_text(), file=sys.stderr)
                    raise
    finally:
        fixture.shutdown()
        fixture.server_close()
    result = dict(runs["stdin_devnull"])
    result.update(
        {
            "ok": True,
            "indexes": stats,
            "embedding_backend": "local test fixture",
            "startup_modes": runs,
        }
    )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
