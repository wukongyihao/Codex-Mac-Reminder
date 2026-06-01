#!/bin/zsh
mkdir -p /Users/xiaoming/.codex/log
LOG=/Users/xiaoming/.codex/log/codex-breathing-light-wrapper.log
REQUEST=/Users/xiaoming/.codex/codex-reminder-request.json
echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] request $*" >> "$LOG"
/usr/bin/python3 - "$REQUEST" "$@" <<'PY' >> "$LOG" 2>&1
import json
import os
import sys
import time

path = sys.argv[1]
payload = {
    "id": time.time_ns(),
    "arguments": sys.argv[2:],
}
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False)
os.replace(tmp, path)
PY
exit 0
