#!/usr/bin/env python3
"""
oneflow-health-probe.py — periodic health probe.
Every run logs a structured JSON record per check via oneflow_logger.
Promtail picks up Docker stdout (via systemd journal) and ships to Loki.

Exits 0 if all checks pass, 1 otherwise.
"""
from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
from typing import Any

sys.path.insert(0, "/usr/local/lib/oneflow")
from oneflow_logger import get_logger  # type: ignore

log = get_logger("health-probe", host=socket.gethostname(), probe_run_id=str(int(time.time())))


def _sh(cmd: list[str]) -> tuple[int, str]:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        return r.returncode, (r.stdout or r.stderr).strip()
    except Exception as e:
        return -1, repr(e)


def check_disk() -> dict[str, Any]:
    total, used, free = shutil.disk_usage("/")
    pct_free = free / total
    ok = pct_free > 0.10
    return {"check": "disk_root", "ok": ok, "pct_free": round(pct_free, 3), "free_gb": round(free / 1024**3, 1)}


def check_memory() -> dict[str, Any]:
    try:
        with open("/proc/meminfo") as f:
            mem = {l.split(":")[0]: int(l.split()[1]) for l in f if l.split(":")[0] in ("MemTotal", "MemAvailable")}
        pct = mem["MemAvailable"] / mem["MemTotal"]
        return {"check": "memory", "ok": pct > 0.10, "pct_available": round(pct, 3)}
    except Exception as e:
        return {"check": "memory", "ok": False, "error": str(e)}


def check_critical_containers() -> dict[str, Any]:
    rc, out = _sh(["docker", "ps", "--format", "{{.Names}}|{{.Status}}"])
    expected = {"prometheus", "alertmanager", "loki", "promtail", "grafana", "node-exporter", "cadvisor", "postgres", "postiz-postgres", "glitchtip-postgres-1"}
    found = {}
    for line in out.splitlines():
        if "|" in line:
            name, status = line.split("|", 1)
            found[name] = status
    missing = sorted(expected - set(found.keys()))
    not_up = sorted(n for n in expected & set(found.keys()) if not found[n].startswith("Up"))
    return {
        "check": "critical_containers",
        "ok": not missing and not not_up,
        "missing": missing,
        "not_up": not_up,
        "expected_count": len(expected),
        "found_up": len(expected) - len(missing) - len(not_up),
    }


def check_caddy_oneflow() -> dict[str, Any]:
    try:
        with urllib.request.urlopen("https://oneflow.cz", timeout=10) as r:
            return {"check": "oneflow_https", "ok": r.status == 200, "status": r.status}
    except Exception as e:
        return {"check": "oneflow_https", "ok": False, "error": type(e).__name__}


def check_loki_ready() -> dict[str, Any]:
    try:
        with urllib.request.urlopen("http://localhost:3100/ready", timeout=5) as r:
            return {"check": "loki_ready", "ok": r.status == 200}
    except Exception as e:
        return {"check": "loki_ready", "ok": False, "error": type(e).__name__}


def check_prometheus_ready() -> dict[str, Any]:
    try:
        with urllib.request.urlopen("http://localhost:9090/-/ready", timeout=5) as r:
            return {"check": "prometheus_ready", "ok": r.status == 200}
    except Exception as e:
        return {"check": "prometheus_ready", "ok": False, "error": type(e).__name__}


def check_backup_freshness() -> dict[str, Any]:
    try:
        files = sorted(
            (os.path.join(d, f) for d, _, fs in os.walk("/var/backups/oneflow") for f in fs if f.endswith(".tar.age")),
            key=os.path.getmtime,
            reverse=True,
        )
        if not files:
            return {"check": "backup_freshness", "ok": False, "error": "no_backup"}
        age_h = (time.time() - os.path.getmtime(files[0])) / 3600
        return {"check": "backup_freshness", "ok": age_h < 25, "age_hours": round(age_h, 1), "latest": os.path.basename(files[0])}
    except Exception as e:
        return {"check": "backup_freshness", "ok": False, "error": str(e)}


CHECKS = [check_disk, check_memory, check_critical_containers, check_caddy_oneflow, check_loki_ready, check_prometheus_ready, check_backup_freshness]


def main() -> int:
    overall = True
    summary = {}
    for fn in CHECKS:
        try:
            res = fn()
        except Exception as e:
            res = {"check": fn.__name__, "ok": False, "error": str(e)}
        ok = bool(res.get("ok"))
        overall = overall and ok
        summary[res["check"]] = ok
        level = "info" if ok else "error"
        getattr(log, level)("probe", extra=res)

    log.info("probe_complete", extra={"overall_ok": overall, "summary": summary})

    # Textfile metric for Prometheus
    tf_dir = "/var/lib/node_exporter/textfile_collector"
    try:
        os.makedirs(tf_dir, exist_ok=True)
        path = os.path.join(tf_dir, "oneflow_health_probe.prom")
        with open(path + ".tmp", "w") as f:
            f.write("# HELP oneflow_health_probe_overall_ok 1 if all checks passed\n")
            f.write("# TYPE oneflow_health_probe_overall_ok gauge\n")
            f.write(f"oneflow_health_probe_overall_ok {1 if overall else 0}\n")
            f.write("# HELP oneflow_health_probe_last_run_timestamp_seconds Last probe run unix time\n")
            f.write("# TYPE oneflow_health_probe_last_run_timestamp_seconds gauge\n")
            f.write(f"oneflow_health_probe_last_run_timestamp_seconds {int(time.time())}\n")
            f.write("# HELP oneflow_health_check_ok Per-check result\n")
            f.write("# TYPE oneflow_health_check_ok gauge\n")
            for name, ok in summary.items():
                f.write(f'oneflow_health_check_ok{{check="{name}"}} {1 if ok else 0}\n')
        os.replace(path + ".tmp", path)
        os.chmod(path, 0o644)
    except Exception as e:
        log.error("textfile_write_failed", extra={"error": str(e)})

    return 0 if overall else 1


if __name__ == "__main__":
    sys.exit(main())
