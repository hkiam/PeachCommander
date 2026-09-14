#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""container-state.py — what state the fixture engine says a container is in.
Used as a regress.py EXTERNAL_CHECK: the witness for a lifecycle action is the engine, not the app.
    container-state.py <name>
"""
import json, socket, sys

name = sys.argv[1]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sys.argv[2] if len(sys.argv) > 2 else "/Users/admin/pcd.sock")
s.sendall(b"GET /v1.44/containers/json?all=true HTTP/1.1\r\nHost: docker\r\n"
          b"Connection: close\r\n\r\n")
data = b""
while True:
    chunk = s.recv(65536)
    if not chunk:
        break
    data += chunk
body = data.split(b"\r\n\r\n", 1)[1]
print(next((c["State"] for c in json.loads(body) if c["Names"] == ["/" + name]), "missing"))
