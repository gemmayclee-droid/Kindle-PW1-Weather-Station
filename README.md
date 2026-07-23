# Kindle PW1 Weather Station

Kindle Paperwhite 1 weather station extension. It renders Shanghai weather, the next 8 hourly forecasts, and the next 3 days to a grayscale `weather.png`, then displays it on the Kindle E Ink screen.

Kindle Paperwhite 1 天氣站擴充套件。它會把上海天氣、未來 8 小時逐小時預報、未來 3 天預報渲染成灰階 `weather.png`，並顯示在 Kindle E Ink 螢幕上。

## Features / 功能

- Current weather, temperature, humidity, date, time, and battery percentage
- 當前天氣、溫度、濕度、日期、時間與電池百分比
- Next 8 hours with one row per hour, plus next 3 days
- 未來 8 小時逐小時顯示，並顯示未來 3 天預報
- Chinese or English display selected from `config.xml`
- 可在 `config.xml` 選擇中文或英文顯示
- Open-Meteo hourly forecast, no API key required
- 使用 Open-Meteo 小時預報，不需要 API key
- Wi-Fi turns on only during refresh, then turns off again
- 只在更新時開啟 Wi-Fi，完成後自動關閉
- Single-shot worker exits after each refresh so Kindle can sleep
- 單次更新完成後 worker 會退出，讓 Kindle 可以休眠
- Optional cron schedule for low-power 4-hour refreshes
- 可安裝低耗電 4 小時定時更新

## Files / 檔案

- `render.py` - Fetches Open-Meteo data, reads battery percentage, and renders `weather.png`
- `worker.sh` - Runs one Wi-Fi/weather/E Ink refresh, then exits
- `start.sh` - Runs one manual refresh
- `schedule.sh` - Installs the low-power cron schedule and runs one immediate refresh
- `unschedule.sh` - Removes the cron schedule and restores low-power settings
- `config.xml` - KUAL extension metadata and weather settings
- `menu.json` - KUAL menu configuration
- `font.ttc` - Font used for CJK/weather text rendering
- `weather.png` - Generated sample image for preview; Kindle will regenerate it at runtime

## Setup / 安裝

1. Copy the project files to Kindle:

   將專案檔案複製到 Kindle：

   ```text
   /mnt/us/extensions/weatheriot
   ```

2. Edit `config.xml`:

   修改 `config.xml`：

   ```xml
   <city>Shanghai</city>
   <lat>31.2304</lat>
   <lon>121.4737</lon>
   <lang>zh</lang>
   <interval>14400</interval>
   ```

   `lang` controls the rendered display language:

   `lang` 控制圖片顯示語言：

   - `zh` - Chinese / 中文
   - `en` - English / 英文

   `interval` is in seconds. `14400` means 4 hours.

   `interval` 單位是秒，`14400` 表示 4 小時。

3. From KUAL, open `Weather Clock` and choose:

   在 KUAL 開啟 `Weather Clock`，選擇：

   - `Update Once` - refresh immediately / 立即更新一次
   - `Install 4h Schedule` - refresh now and then every 4 hours / 立即更新並安裝每 4 小時定時更新
   - `Remove Schedule` - stop automatic refreshes / 停止自動更新

## Requirements / 需求

- Jailbroken Kindle Paperwhite 1
- KUAL
- Python 3 on Kindle
- Python packages: `requests`, `Pillow`
- No weather API key is required

## Notes / 注意事項

- `weather.png` is included as a generated preview image. Runtime updates will overwrite it on Kindle.
- `weather.png` 是預覽用生成圖片；Kindle 實際執行時會覆寫它。
- `weather.tmp.png`, `log.txt`, and runtime diagnostics should stay local.
- `weather.tmp.png`、`log.txt` 與執行診斷檔應留在本機。
- `worker.sh` does not stay resident. It turns Wi-Fi off, restores `preventScreenSaver`, updates the image, and exits after each run.
- `worker.sh` 不會常駐；每次更新後會關 Wi-Fi、恢復 `preventScreenSaver`，然後退出。
