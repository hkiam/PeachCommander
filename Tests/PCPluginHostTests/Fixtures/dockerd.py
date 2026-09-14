#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""dockerd.py — a Docker Engine API stand-in on a Unix socket, for the Docker plugin's tests.

Speaks the parts of the engine API the plugin uses, over a real AF_UNIX socket, backed by real
directories on disk. The point is not to be Docker; it is to answer the way Docker answers,
*including the three things that are easy to get wrong and cost a day each when you do*:

  * A **HEAD** carries the `Content-Length` a GET would have had and sends **no body**. A client
    that reads that many bytes waits forever. Every `PfxStat` in the plugin is a HEAD, so this
    fixture sends the header deliberately and writes nothing after it.
  * `GET …/archive` of a directory is **recursive** — the whole subtree, depth first — which is
    what makes a container's "/" expensive and is the reason the plugin has a budget at all.
  * `POST /exec/{id}/start` answers with a **stream with no framing at all**: no Content-Length,
    no chunked encoding, multiplexed 8-byte-headed frames, ending when the socket closes.

    Usage: dockerd.py <root> <socket-path>

`<root>/spec.json` describes the engine:

    {
      "containers": [
        {"name": "stack-web-1", "state": "running", "image": "nginx",
         "labels": {"com.docker.compose.project": "stack", "com.docker.compose.service": "web"},
         "mounts": [{"Type": "volume", "Name": "stack_data", "Destination": "/data", "RW": true}],
         "readOnlyRootfs": false,
         "root": "web"}                      # <root>/fs/web is its filesystem
      ],
      "volumes": [{"name": "stack_data", "root": "vol-data",
                   "labels": {"com.docker.compose.project": "stack"}}],
      "images": ["alpine:3"],
      "denyWrites": ["/locked"]              # paths exec refuses, as a non-root user would
    }
"""
import base64
import json
import os
import io
import socketserver
import stat
import sys
import tarfile
import time
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs, unquote

ROOT = sys.argv[1]
SOCKET_PATH = sys.argv[2]
SPEC = json.load(open(os.path.join(ROOT, "spec.json"), encoding="utf-8"))

# Containers created at run time (the plugin's volume helpers land here).
CREATED = {}


def containers():
    """Everything the engine would list, spec'd plus created."""
    return list(SPEC.get("containers", [])) + list(CREATED.values())


def find_container(ident):
    for c in containers():
        if ident in (c["name"], c.get("id", c["name"])):
            return c
    return None


def container_fs(c):
    """The directory that stands in for the container's filesystem."""
    if "volumeRoot" in c:        # a helper created around a volume
        return c["volumeRoot"]
    return os.path.join(ROOT, "fs", c["root"])


def volume_fs(name):
    for v in SPEC.get("volumes", []):
        if v["name"] == name:
            return os.path.join(ROOT, "fs", v["root"])
    return None


def resolve(c, path):
    """A path inside a container, mapped onto the fixture's disk.

    A mount whose destination is a prefix of the path is redirected to the volume's own directory,
    which is how a real engine behaves and what the plugin's volume access depends on.
    """
    path = "/" + path.strip("/")
    for mount in c.get("mounts", []):
        destination = mount["Destination"].rstrip("/")
        if path == destination or path.startswith(destination + "/"):
            base = volume_fs(mount["Name"])
            if base:
                return os.path.join(base, path[len(destination):].strip("/"))
    if "volumeRoot" in c and path.startswith("/peachcommander-volume"):
        return os.path.join(c["volumeRoot"], path[len("/peachcommander-volume"):].strip("/"))
    return os.path.join(container_fs(c), path.strip("/"))


GO_MODE_DIR = 1 << 31
GO_MODE_SYMLINK = 1 << 27


def go_mode(st):
    """A POSIX mode as Go's os.FileMode, which is what the engine reports."""
    mode = stat.S_IMODE(st.st_mode)
    if stat.S_ISDIR(st.st_mode):
        mode |= GO_MODE_DIR
    elif stat.S_ISLNK(st.st_mode):
        mode |= GO_MODE_SYMLINK
    return mode


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def address_string(self):
        # BaseHTTPRequestHandler reads client_address[0], which is "" on an AF_UNIX socket.
        return "unix"

    # ---- plumbing ------------------------------------------------------

    def _json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Api-Version", "1.44")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _error(self, status, message):
        self._json({"message": message}, status=status)

    def _empty(self, status=204):
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _strip_version(self):
        path = urlparse(self.path).path
        if path.startswith("/v1."):
            path = path[path.index("/", 1):]
        return path

    def _query(self):
        return {k: v[0] for k, v in parse_qs(urlparse(self.path).query).items()}

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    # ---- routes --------------------------------------------------------

    def do_HEAD(self):
        path = self._strip_version()
        if path == "/_ping":
            self.send_response(200)
            self.send_header("Api-Version", "1.44")
            self.send_header("Server", "Docker/fixture (linux)")
            # Deliberately the Content-Length of what a GET would answer, with no body after it —
            # exactly what the real daemon does, and the trap this fixture exists to reproduce.
            self.send_header("Content-Length", "2")
            self.end_headers()
            return
        if path.startswith("/containers/") and path.endswith("/archive"):
            self._archive_stat(path.split("/")[2], head_only=True)
            return
        self._empty(404)

    def do_GET(self):
        path = self._strip_version()
        query = self._query()
        if path == "/_ping":
            self.send_response(200)
            self.send_header("Api-Version", "1.44")
            self.send_header("Content-Length", "2")
            self.end_headers()
            self.wfile.write(b"OK")
        elif path == "/containers/json":
            self._json([self._container_json(c) for c in containers()])
        elif path == "/volumes":
            self._json({"Volumes": [self._volume_json(v) for v in SPEC.get("volumes", [])]})
        elif path == "/images/json":
            self._json([{"Id": "sha256:fixture", "RepoTags": SPEC.get("images", ["alpine:3"])}])
        elif path.startswith("/containers/") and path.endswith("/json"):
            self._inspect(path.split("/")[2])
        elif path.startswith("/containers/") and path.endswith("/archive"):
            self._archive_get(path.split("/")[2], unquote(query.get("path", "/")))
        elif path.startswith("/exec/") and path.endswith("/json"):
            self._json({"ExitCode": EXECS.get(path.split("/")[2], {}).get("exit", 0),
                        "Running": False})
        else:
            self._error(404, "no such endpoint: " + path)

    def do_POST(self):
        path = self._strip_version()
        query = self._query()
        body = self._body()
        if path == "/containers/create":
            self._create(query.get("name", "unnamed"), json.loads(body or b"{}"))
        elif path.startswith("/containers/") and path.endswith("/exec"):
            self._exec_create(path.split("/")[2], json.loads(body or b"{}"))
        elif path.startswith("/exec/") and path.endswith("/start"):
            self._exec_start(path.split("/")[2])
        else:
            self._error(404, "no such endpoint: " + path)

    def do_PUT(self):
        path = self._strip_version()
        query = self._query()
        body = self._body()
        if path.startswith("/containers/") and path.endswith("/archive"):
            self._archive_put(path.split("/")[2], unquote(query.get("path", "/")), body)
        else:
            self._error(404, "no such endpoint: " + path)

    def do_DELETE(self):
        path = self._strip_version()
        if path.startswith("/containers/"):
            ident = path.split("/")[2]
            for key, value in list(CREATED.items()):
                if ident in (key, value["name"]):
                    del CREATED[key]
            self._empty(204)
        else:
            self._error(404, "no such endpoint: " + path)

    # ---- payloads ------------------------------------------------------

    def _container_json(self, c):
        return {
            "Id": c.get("id", c["name"]),
            "Names": ["/" + c["name"]],
            "Image": c.get("image", "scratch"),
            "State": c.get("state", "running"),
            "Status": c.get("status", ""),
            "Labels": c.get("labels", {}),
            "Mounts": c.get("mounts", []),
        }

    def _volume_json(self, v):
        return {
            "Name": v["name"],
            "Driver": "local",
            "Mountpoint": "/var/lib/docker/volumes/%s/_data" % v["name"],
            "Labels": v.get("labels", {}),
            "CreatedAt": "2026-01-02T03:04:05Z",
        }

    def _inspect(self, ident):
        c = find_container(ident)
        if not c:
            return self._error(404, "No such container: " + ident)
        self._json({"Id": c.get("id", c["name"]), "Name": "/" + c["name"],
                    "State": {"Status": c.get("state", "running")},
                    "HostConfig": {"ReadonlyRootfs": c.get("readOnlyRootfs", False)}})

    def _create(self, name, spec):
        binds = (spec.get("HostConfig") or {}).get("Binds") or []
        volume_root = None
        for bind in binds:
            parts = bind.split(":")
            if len(parts) >= 2:
                volume_root = volume_fs(parts[0])
        made = {"name": name, "id": "created-" + name, "state": "created",
                "image": spec.get("Image", ""), "labels": spec.get("Labels", {}),
                "mounts": [], "root": "__created__"}
        if volume_root:
            made["volumeRoot"] = volume_root
        CREATED[made["id"]] = made
        self._json({"Id": made["id"], "Warnings": []}, status=201)

    # ---- archive -------------------------------------------------------

    def _archive_stat(self, ident, head_only):
        c = find_container(ident)
        query = self._query()
        path = unquote(query.get("path", "/"))
        if not c:
            return self._empty(404)
        target = resolve(c, path)
        try:
            st = os.lstat(target)
        except OSError:
            return self._empty(404)
        payload = {
            "name": os.path.basename(target.rstrip("/")) or "/",
            "size": st.st_size,
            "mode": go_mode(st),
            "mtime": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(st.st_mtime)),
            "linkTarget": os.readlink(target) if stat.S_ISLNK(st.st_mode) else "",
        }
        self.send_response(200)
        self.send_header("Content-Type", "application/x-tar")
        self.send_header("X-Docker-Container-Path-Stat",
                         base64.b64encode(json.dumps(payload).encode()).decode())
        # The same trap again, on the endpoint the plugin stats through.
        self.send_header("Content-Length", "10240")
        self.end_headers()

    def _archive_get(self, ident, path):
        c = find_container(ident)
        if not c:
            return self._error(404, "No such container: " + ident)
        target = resolve(c, path)
        if not os.path.lexists(target):
            return self._error(404, "Could not find the file %s in container" % path)

        buffer = io.BytesIO()
        base = os.path.basename(target.rstrip("/")) or "/"
        with tarfile.open(fileobj=buffer, mode="w", format=tarfile.USTAR_FORMAT) as tar:
            # Recursive, like the real engine — which is the whole reason the plugin budgets it.
            tar.add(target, arcname=base, recursive=True)
        data = buffer.getvalue()

        # Chunked, because the engine streams a large archive that way and the plugin's reader has
        # to cope with both framings.
        self.send_response(200)
        self.send_header("Content-Type", "application/x-tar")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        step = 8192
        for offset in range(0, len(data), step):
            piece = data[offset:offset + step]
            self.wfile.write(b"%x\r\n" % len(piece) + piece + b"\r\n")
        self.wfile.write(b"0\r\n\r\n")

    def _archive_put(self, ident, path, body):
        c = find_container(ident)
        if not c:
            return self._error(404, "No such container: " + ident)
        if c.get("readOnlyRootfs"):
            return self._error(403, "container rootfs is marked read-only")
        target = resolve(c, path)
        if not os.path.isdir(target):
            return self._error(404, "extraction point is not a directory")
        try:
            with tarfile.open(fileobj=io.BytesIO(body), mode="r") as tar:
                for member in tar.getmembers():
                    # Refuse an entry carrying extended attributes, which is what BSD tar produces
                    # and what the real engine rejects with a 500 *after* writing the file.
                    if member.pax_headers:
                        return self._error(500, 'lsetxattr: operation not supported')
                    tar.extract(member, path=target, set_attrs=False)
        except tarfile.TarError as error:
            return self._error(400, "bad tar: %s" % error)
        self._empty(200)

    # ---- exec ----------------------------------------------------------

    def _exec_create(self, ident, spec):
        c = find_container(ident)
        if not c:
            return self._error(404, "No such container: " + ident)
        if c.get("state", "running") != "running":
            return self._error(409, "container %s is not running" % ident)
        token = "exec-%d" % (len(EXECS) + 1)
        EXECS[token] = {"container": c, "argv": spec.get("Cmd", []), "exit": 0}
        self._json({"Id": token}, status=201)

    def _exec_start(self, token):
        job = EXECS.get(token)
        if not job:
            return self._error(404, "No such exec instance")
        out, err, code = run_tool(job["container"], job["argv"])
        job["exit"] = code
        # No Content-Length and no chunked encoding, multiplexed frames, ends at EOF — the real
        # shape of an attached exec, and a framing the plugin has to recognise by its absence.
        self.send_response(200)
        self.send_header("Content-Type", "application/vnd.docker.raw-stream")
        self.end_headers()
        for stream, payload in ((1, out), (2, err)):
            if payload:
                self.wfile.write(bytes([stream, 0, 0, 0]) + len(payload).to_bytes(4, "big") + payload)
        self.close_connection = True


EXECS = {}


def run_tool(container, argv):
    """The handful of utilities the plugin ever runs, carried out on the fixture's disk."""
    if not argv:
        return b"", b"no command\n", 127
    tool = os.path.basename(argv[0])
    args = argv[1:]
    if tool == "busybox" and args:
        tool, args = args[0], args[1:]
    # A binary the image does not have: the engine reports this as a failure to start.
    if tool not in SPEC.get("tools", ["ls", "rm", "mv"]):
        return b"", b'exec: "%s": stat: no such file or directory\n' % tool.encode(), 126
    operands = [a for a in args if not a.startswith("-") and a != "--"]

    def denied(path):
        for locked in SPEC.get("denyWrites", []):
            if path == locked or path.startswith(locked.rstrip("/") + "/"):
                return True
        return False

    try:
        if tool == "ls":
            target = resolve(container, operands[0] if operands else "/")
            return ("\n".join(sorted(os.listdir(target))) + "\n").encode(), b"", 0
        if tool == "rm":
            if denied(operands[0]):
                return b"", b"rm: can't remove '%s': Operation not permitted\n" % operands[0].encode(), 1
            target = resolve(container, operands[0])
            if os.path.isdir(target) and not os.path.islink(target):
                import shutil
                shutil.rmtree(target)
            elif os.path.lexists(target):
                os.remove(target)
            return b"", b"", 0
        if tool == "mv":
            if denied(operands[0]) or denied(operands[1]):
                return b"", b"mv: can't rename '%s': Operation not permitted\n" % operands[0].encode(), 1
            os.rename(resolve(container, operands[0]), resolve(container, operands[1]))
            return b"", b"", 0
    except OSError as error:
        return b"", ("%s: %s\n" % (tool, error)).encode(), 1
    return b"", b"unsupported\n", 127


class Server(socketserver.ThreadingUnixStreamServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)
    server = Server(SOCKET_PATH, Handler)
    # The Swift side waits for this file rather than sleeping a guessed amount: a fixed wait is
    # either slow or occasionally short, and "occasionally short" reads as the plugin refusing to
    # connect.
    with open(SOCKET_PATH + ".ready", "w", encoding="utf-8") as handle:
        handle.write("ready")
    server.serve_forever()


if __name__ == "__main__":
    main()
