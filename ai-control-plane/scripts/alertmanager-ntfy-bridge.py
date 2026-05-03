#!/usr/bin/env python3
"""
alertmanager-ntfy-bridge.py
Tiny webhook receiver that converts Alertmanager v1 payload to a
human-readable ntfy push (with Bearer auth + tags/priority).

Env:
  NTFY_URL    base url, e.g. https://ntfy.oneflow.cz
  NTFY_TOPIC  topic name (default: Filip)
  NTFY_TOKEN  bearer token for ntfy
  LISTEN_PORT default 9094

Endpoint: POST /alert  (called by Alertmanager webhook_configs.url)
Health:   GET  /health
"""
import json
import os
import sys
import urllib.request
import urllib.error
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NTFY_URL = os.environ.get("NTFY_URL", "https://ntfy.oneflow.cz").rstrip("/")
NTFY_TOPIC = os.environ.get("NTFY_TOPIC", "Filip")
NTFY_TOKEN = os.environ.get("NTFY_TOKEN", "")
LISTEN_PORT = int(os.environ.get("LISTEN_PORT", "9094"))

SEVERITY_PRIO = {"critical": "5", "warning": "3", "info": "2"}
SEVERITY_EMOJI = {"critical": "🚨", "warning": "⚠️", "info": "ℹ️"}


def _ascii_safe(s):
    # ntfy v2 supports RFC 2047 for headers; ASCII fallback is safest
    return s.encode("ascii", "replace").decode("ascii")


def push_ntfy(title, body, priority="3", tags="bell"):
    req = urllib.request.Request(
        f"{NTFY_URL}/{NTFY_TOPIC}",
        data=body.encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {NTFY_TOKEN}",
            "Title": _ascii_safe(title)[:128],
            "Priority": priority,
            "Tags": tags,
            "Markdown": "yes",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read(200).decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read(500).decode("utf-8", errors="replace")
    except Exception as e:
        msg = f"{type(e).__name__}: {e}"
        sys.stderr.write(f"[bridge] push_ntfy ERR: {msg}\n")
        return 0, msg[:200]


def format_alert(alert):
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    name = labels.get("alertname", "alert")
    severity = labels.get("severity", "info")
    instance = labels.get("instance", "?")
    summary = annotations.get("summary", "")
    description = annotations.get("description", "")
    runbook = labels.get("runbook", "")
    state = alert.get("status", "firing")

    emoji = SEVERITY_EMOJI.get(severity, "•")
    state_marker = "RESOLVED" if state == "resolved" else "FIRING"
    title = f"{emoji} [{state_marker} {severity}] {name} @ {instance}"
    body_lines = [summary] if summary else []
    if description:
        body_lines.append("")
        body_lines.append(description)
    if runbook:
        body_lines.append("")
        body_lines.append(f"runbook: `{runbook}`")
    body = "\n".join(body_lines) or f"{name} on {instance}"
    priority = SEVERITY_PRIO.get(severity, "3")
    tags = "rotating_light" if state == "firing" else "white_check_mark"
    return title, body, priority, tags


class Handler(BaseHTTPRequestHandler):
    def _reply(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def do_GET(self):
        if self.path == "/health":
            return self._reply(200, "ok")
        return self._reply(404, "not found")

    def do_POST(self):
        if self.path != "/alert":
            return self._reply(404, "not found")
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception as e:
            return self._reply(400, f"bad json: {e}")

        results = []
        for a in payload.get("alerts", []):
            title, body, prio, tags = format_alert(a)
            code, txt = push_ntfy(title, body, prio, tags)
            results.append(f"{code} {a.get('labels',{}).get('alertname','?')}")
        return self._reply(200, "; ".join(results) or "no alerts")

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[bridge] {self.address_string()} - {fmt % args}\n")


def main():
    if not NTFY_TOKEN:
        print("ERROR: NTFY_TOKEN required", file=sys.stderr)
        sys.exit(1)
    print(f"[bridge] listening on :{LISTEN_PORT} -> {NTFY_URL}/{NTFY_TOPIC}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", LISTEN_PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
