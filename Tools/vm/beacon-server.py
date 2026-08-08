#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""beacon-server.py — the witness for the viewer's network block (F-116).

A Markdown or HTML file the user previews can contain `<img src="http://…/x.png?who=…">`. Nothing has
to be clicked and no script has to run: rendering the page fetches it, and the server on the other end
now knows that this person opened this document, and from which address. The viewer's own comment said
that could not happen because JavaScript is disabled — measured, and wrong.

Whether the block works cannot be asked of the app, and a screenshot cannot show it either: the
difference between blocked and not blocked is a request that either arrives somewhere or does not. So
this listens, records what it is asked for, and the harness reads the log afterwards.

It answers a *self-test* request during setup as well, so "no hit from the viewer" can be told apart
from "the server was never running" — otherwise the scenario would pass most convincingly when the
witness was dead.

Started by regress.py during setup; writes ~/beacon-hits.log, one line per request.
"""
from __future__ import annotations

import base64
import http.server
import pathlib

LOG = pathlib.Path.home() / "beacon-hits.log"
PORT = 8731

# A 1×1 PNG, so a fetch that is *not* blocked also succeeds and looks entirely ordinary.
PIXEL = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):                                    # noqa: N802 (stdlib naming)
        with LOG.open("a", encoding="utf-8") as log:
            log.write(self.path + "\n")
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(PIXEL)))
        self.end_headers()
        self.wfile.write(PIXEL)

    def log_message(self, *args):                        # keep the guest's console quiet
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
