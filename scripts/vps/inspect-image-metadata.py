#!/usr/bin/env python3
"""Check Docker image metadata without printing environment values or history."""

from __future__ import annotations

import json
import re
import sys

SENSITIVE_NAME = re.compile(
    r"(?:^|_)(?:PASSWORD|PASSWD|SECRET|TOKEN|API_KEY|PRIVATE_KEY|ACCESS_KEY)(?:_|$)|^DATABASE_URL$|^REDIS_URL$",
    re.IGNORECASE,
)
SECRET_VALUE = re.compile(
    r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"
    r"|\bAKIA[0-9A-Z]{16}\b"
    r"|\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{22,})\b"
    r"|\bsk-[A-Za-z0-9_-]{20,}\b"
)
PLACEHOLDER = re.compile(
    r"^(?:\$\{[^}]+\}|<[^>]+>|REPLACE(?:_WITH)?_.*|CHANGEME|CHANGE_ME|YOUR_.*|\*{3,})$",
    re.IGNORECASE,
)


def looks_sensitive(name: str, value: str) -> bool:
    if not value.strip() or PLACEHOLDER.fullmatch(value.strip()):
        return False
    return bool(SENSITIVE_NAME.search(name) or SECRET_VALUE.search(value))


def check_env(entries: object) -> bool:
    if entries is None:
        return False
    if not isinstance(entries, list):
        raise ValueError
    for item in entries:
        if not isinstance(item, str) or "=" not in item:
            continue
        name, value = item.split("=", 1)
        if looks_sensitive(name, value):
            return True
    return False


def check_history(history: str) -> bool:
    if SECRET_VALUE.search(history):
        return True
    assignment = re.compile(
        r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^\s,;]+)"
    )
    for name, value in assignment.findall(history):
        if looks_sensitive(name, value.strip("\"'`")):
            return True
    return False


def main() -> int:
    if len(sys.argv) != 2 or sys.argv[1] not in {"inspect", "history"}:
        print("Invalid metadata check mode.", file=sys.stderr)
        return 2
    data = sys.stdin.read()
    if sys.argv[1] == "history":
        if check_history(data):
            print("Image build history contains a possible secret.", file=sys.stderr)
            return 1
        print("Build history scan passed.")
        return 0
    try:
        parsed = json.loads(data)
        image = parsed[0] if isinstance(parsed, list) else parsed
        if not isinstance(image, dict):
            raise ValueError
        config = image.get("Config") or {}
        if check_env(config.get("Env")):
            print("Image Config.Env contains a possible secret.", file=sys.stderr)
            return 1
        labels = config.get("Labels") or {}
        values = [
            image.get("Id", ""),
            image.get("Os", ""),
            image.get("Architecture", ""),
            labels.get("org.opencontainers.image.revision", ""),
            labels.get("org.opencontainers.image.source", ""),
            config.get("User", ""),
        ]
        print("\n".join(str(value) for value in values))
        return 0
    except (json.JSONDecodeError, IndexError, TypeError, ValueError):
        print("Docker image metadata could not be safely inspected.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
