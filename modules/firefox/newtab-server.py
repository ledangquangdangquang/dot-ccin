#!/usr/bin/env python3
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("NEWTAB_PORT", "8918"))
DIRECTORY = os.environ.get("NEWTAB_DIR", os.path.expanduser("~/.config/newtab"))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


if __name__ == "__main__":
    os.chdir(DIRECTORY)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()