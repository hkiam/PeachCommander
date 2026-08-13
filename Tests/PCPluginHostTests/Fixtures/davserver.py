#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""A minimal read-only WebDAV origin for WebDAVPluginTests.

Speaks just enough of RFC 4918 for the plugin to connect, enumerate and read:
OPTIONS, PROPFIND (Depth 0/1), HEAD and GET over a directory tree. Deliberately
not a general DAV implementation — it exists so the shipped WebDAV plugin is
exercised against a real socket and real XML instead of being trusted.

Usage: davserver.py <root-dir> <port>
"""
import email.utils
import os
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.abspath(sys.argv[1])
PORT = int(sys.argv[2])


def xml_escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass   # the test reads results, not a request log

    def _local(self):
        path = urllib.parse.unquote(self.path.split("?")[0])
        local = os.path.abspath(os.path.join(ROOT, path.lstrip("/")))
        # Never serve outside the root, whatever the request path claims.
        if local != ROOT and not local.startswith(ROOT + os.sep):
            return None, None
        return path, local

    def _not_found(self):
        self.send_response(404)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def _response_xml(self, href, local):
        is_dir = os.path.isdir(local)
        st = os.stat(local)
        if is_dir and not href.endswith("/"):
            href += "/"
        parts = [
            "<D:response><D:href>%s</D:href><D:propstat><D:prop>"
            % xml_escape(urllib.parse.quote(href)),
            "<D:resourcetype>%s</D:resourcetype>" % ("<D:collection/>" if is_dir else ""),
            "<D:displayname>%s</D:displayname>" % xml_escape(os.path.basename(local.rstrip("/"))),
            "<D:getlastmodified>%s</D:getlastmodified>"
            % email.utils.formatdate(st.st_mtime, usegmt=True),
        ]
        if not is_dir:
            parts.append("<D:getcontentlength>%d</D:getcontentlength>" % st.st_size)
        parts.append("</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>")
        return "".join(parts)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("DAV", "1,2")
        self.send_header("Allow", "OPTIONS, GET, HEAD, PROPFIND")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_PROPFIND(self):
        href, local = self._local()
        length = int(self.headers.get("Content-Length") or 0)
        if length:
            self.rfile.read(length)
        if local is None or not os.path.exists(local):
            return self._not_found()
        body = ['<?xml version="1.0" encoding="utf-8"?><D:multistatus xmlns:D="DAV:">',
                self._response_xml(href, local)]
        if self.headers.get("Depth", "1") == "1" and os.path.isdir(local):
            base = href if href.endswith("/") else href + "/"
            for name in sorted(os.listdir(local)):
                body.append(self._response_xml(base + name, os.path.join(local, name)))
        body.append("</D:multistatus>")
        out = "".join(body).encode("utf-8")
        self.send_response(207, "Multi-Status")
        self.send_header("Content-Type", 'application/xml; charset="utf-8"')
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)

    def do_HEAD(self):
        self._send_file(body=False)

    def do_GET(self):
        self._send_file(body=True)

    def _send_file(self, body):
        _, local = self._local()
        if local is None or not os.path.isfile(local):
            return self._not_found()
        with open(local, "rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if body:
            self.wfile.write(data)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
