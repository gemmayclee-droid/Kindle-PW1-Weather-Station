#!/bin/sh
# 收集 Linkss 掛載與系統螢幕保護路徑資訊；僅讀取，不修改設定。

LOG=/mnt/us/extensions/onlinescreensaver/linkss-diagnostic.log
LINKSS=/mnt/us/linkss

exec > "$LOG" 2>&1

echo "============================================================"
echo "Linkss 診斷開始：$(date)"
echo "執行身分：$(id)"
echo

echo "[ Linkss Upstart 狀態 ]"
status linkss 2>&1 || true
initctl status linkss 2>&1 || true
echo

echo "[ Linkss 相關程序 ]"
ps xa 2>&1 | grep -E '[l]inkss|[u]sb-watchdog|[s]huffless' || true
echo

echo "[ 螢幕保護掛載 ]"
grep -E '/usr/share/blanket/screensaver|/var/local/custom_screensavers|/mnt/us/linkss' /proc/mounts 2>&1 || true
echo

echo "[ Linkss 模式標記 ]"
for marker in auto cover last random shuffle beta mounted_ss mounted_ss_tmpfs mounted_custom_ss mounted_custom_ss_tmpfs; do
	if [ -f "$LINKSS/$marker" ]; then
		echo "存在：$LINKSS/$marker"
	else
		echo "不存在：$LINKSS/$marker"
	fi
done
echo

echo "[ Linkss 機型標記 ]"
ls -la "$LINKSS/etc"/is_a_* 2>&1 || true
echo

echo "[ Linkss 圖片 ]"
ls -la "$LINKSS/screensavers" 2>&1 || true
echo

echo "[ 原生螢幕保護路徑 ]"
ls -la /usr/share/blanket/screensaver 2>&1 || true
echo

echo "[ 自訂螢幕保護路徑 ]"
ls -la /var/local/custom_screensavers 2>&1 || true
echo

echo "[ 電源狀態 ]"
lipc-get-prop com.lab126.powerd status 2>&1 || true
lipc-get-prop com.lab126.powerd preventScreenSaver 2>&1 || true
echo

echo "Linkss 診斷結束：$(date)"
