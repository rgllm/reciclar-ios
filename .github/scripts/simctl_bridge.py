#!/usr/bin/env python3
"""Host-side simctl for the store-capture UI test.

The UI test runs inside the simulator, where Process and xcrun are unavailable.
It posts here over localhost; this process runs on the Mac.
"""

import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

UDID = os.environ["UDID"]
OUT = os.environ["SCREENSHOT_DIR"]
LOCATION = re.compile(r"-?\d+(?:\.\d+)?,-?\d+(?:\.\d+)?")
NAME = re.compile(r"[0-9A-Za-z-]{1,40}")


def simctl(args):
    result = subprocess.run(
        ["xcrun", "simctl", *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "simctl failed").strip()
        raise RuntimeError(detail)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if urlparse(self.path).path == "/health":
            self.respond(200, b"ok")
            return
        self.respond(404, b"not found")

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        parsed = urlparse(self.path)
        try:
            self.route(parsed.path, parsed.query, body)
        except Exception as error:
            message = str(error).encode()
            print(f"bridge error {parsed.path}: {error}", flush=True)
            self.respond(500, message)

    def route(self, path, query, body):
        if path == "/location":
            value = body.decode().strip()
            if LOCATION.fullmatch(value) is None:
                raise RuntimeError(f"invalid location {value!r}")
            simctl(["location", UDID, "set", value])
            print(f"location {value}", flush=True)
        elif path == "/status-bar":
            simctl([
                "status_bar", UDID, "override",
                "--time", "9:41",
                "--dataNetwork", "wifi",
                "--wifiMode", "active",
                "--wifiBars", "3",
                "--cellularMode", "active",
                "--cellularBars", "4",
                "--batteryState", "charged",
                "--batteryLevel", "100",
            ])
            print("status bar overridden", flush=True)
        elif path == "/privacy":
            simctl(["privacy", UDID, "grant", "location", "com.rgllm.reciclar"])
            print("location privacy granted", flush=True)
        elif path == "/screenshot":
            name = parse_qs(query).get("name", ["shot"])[0]
            if NAME.fullmatch(name) is None:
                raise RuntimeError(f"invalid screenshot name {name!r}")
            os.makedirs(OUT, exist_ok=True)
            destination = os.path.join(OUT, f"{name}.png")
            with open(destination, "wb") as handle:
                handle.write(body)
            print(f"wrote {destination} ({len(body)} bytes)", flush=True)
        else:
            self.respond(404, b"not found")
            return
        self.respond(200, b"ok")

    def respond(self, status, payload):
        self.send_response(status)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 8765), Handler)
    print("simctl bridge listening on 127.0.0.1:8765", flush=True)
    server.serve_forever()
