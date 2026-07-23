#!/bin/sh
BASE="/mnt/us/extensions/weatheriot"

# 1. 確保工作目錄正確
cd "$BASE"

# 2. 清空日誌並記錄啟動資訊
echo "=== 手動更新: $(date) ===" > "$BASE/log.txt"

# 3. 殺掉舊的 worker 進程（防止重複執行導致耗電）
pkill -f "$BASE/worker.sh"

# 4. 執行單次更新。若需要自動定時，請執行 schedule.sh。
/bin/sh "$BASE/worker.sh" >> "$BASE/log.txt" 2>&1 &
