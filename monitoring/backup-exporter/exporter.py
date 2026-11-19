#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATUS_FILE = os.environ.get("STATUS_FILE", "/status/last_backup.prom")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/metrics", "/healthz"):
            self.send_error(404)
            return
        if self.path == "/healthz":
            body = b"ok\n"
        else:
            try:
                with open(STATUS_FILE, "rb") as stream:
                    body = stream.read()
            except FileNotFoundError:
                body = (
                    b"# HELP minvault_backup_success Whether the last backup completed successfully.\n"
                    b"# TYPE minvault_backup_success gauge\n"
                    b"minvault_backup_success 0\n"
                )
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        return

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 9101), Handler).serve_forever()
