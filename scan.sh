#!/bin/sh

BASE="/mnt/us/extensions/weatheriot"
OUT="$BASE/environment_scan.txt"

echo "=========================" > "$OUT"
echo " Kindle Environment Scan " >> "$OUT"
echo "=========================" >> "$OUT"
echo "" >> "$OUT"
date >> "$OUT"
echo "" >> "$OUT"

echo "[PATH]" >> "$OUT"
echo "$PATH" >> "$OUT"
echo "" >> "$OUT"

#echo "[which python]" >> "$OUT"
#which python >> "$OUT" 2>&1
#echo "" >> "$OUT"
#
#echo "[python version]" >> "$OUT"
#python --version >> "$OUT" 2>&1
#echo "" >> "$OUT"
#
#echo "[which python3]" >> "$OUT"
#which python3 >> "$OUT" 2>&1
#echo "" >> "$OUT"
#
#echo "[python3 version]" >> "$OUT"
#python3 --version >> "$OUT" 2>&1
#echo "" >> "$OUT"
#
#echo "[real python3 executable]" >> "$OUT"
#ls -l "$(which python3 2>/dev/null)" >> "$OUT" 2>&1
#echo "" >> "$OUT"
#
#echo "[test run python3]" >> "$OUT"
#python3 -c "import sys; print(sys.executable)" >> "$OUT" 2>&1
#echo "" >> "$OUT"
#
#echo "[test powerd property]" >> "$OUT"
#lipc-probe -a com.lab126.powerd >> "$OUT" 2>&1
#echo "" >> "$OUT"
#

echo "[測試耗電來源]" >> "$OUT"
ps aux >> "$OUT" 2>&1
ps aux | grep cvm >> "$OUT" 2>&1
echo "" >> "$OUT"

echo "[測試Wi-Fi]" >> "$OUT"
ifconfig -a >> "$OUT" 2>&1
echo "" >> "$OUT"
iwconfig >> "$OUT" 2>&1
echo "" >> "$OUT"
echo "DONE" >> "$OUT"