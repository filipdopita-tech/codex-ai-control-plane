"""ntfy push notifications — Filipův kanál."""
from __future__ import annotations

import os
import urllib.request
from typing import List, Optional

DEFAULT_NTFY = os.environ.get("NTFY_URL", "https://ntfy.oneflow.cz/Filip")


def push(
    title: str,
    message: str,
    tags: Optional[List[str]] = None,
    priority: int = 3,
    click_url: Optional[str] = None,
    ntfy_url: str = DEFAULT_NTFY,
) -> bool:
    """Send ntfy push. Returns True on HTTP 200."""
    headers = {
        "Title": title.encode("utf-8"),
        "Priority": str(priority),
    }
    if tags:
        headers["Tags"] = ",".join(tags)
    if click_url:
        headers["Click"] = click_url
    req = urllib.request.Request(
        ntfy_url,
        data=message.encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return 200 <= r.status < 300
    except Exception as e:
        print(f"  [ntfy ERR] {e}")
        return False
