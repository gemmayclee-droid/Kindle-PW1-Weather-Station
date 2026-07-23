#!/bin/sh
BASE="/mnt/us/extensions/weatheriot"

cd "$BASE" || exit 1

echo "=== 手動更新: $(date) ===" > "$BASE/log.txt"

# 單次更新只跑 worker.sh 一次；不安裝、不移除 4 小時排程。
/bin/sh "$BASE/worker.sh" >> "$BASE/log.txt" 2>&1 &
