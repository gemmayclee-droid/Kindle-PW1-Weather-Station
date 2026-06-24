#!/bin/sh
BASE="/mnt/us/extensions/weatheriot"

# 1. 確保工作目錄正確
cd "$BASE"

# 2. 清空日誌並記錄啟動資訊
echo "=== 系統重啟: $(date) ===" > "$BASE/log.txt"

# 3. 殺掉舊的 worker 進程（防止重複執行導致系統變慢）
pkill -f "worker.sh"

# 4. 啟動 worker.sh
/bin/sh "$BASE/worker.sh" >> "$BASE/log.txt" 2>&1 &