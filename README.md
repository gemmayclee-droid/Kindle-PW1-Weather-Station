# Kindle PW1 Weather Station

<p align="center">
  <a href="#中文"><strong>中文</strong></a>
  ·
  <a href="#english"><strong>English</strong></a>
</p>

---

## 中文

<p align="center">
  <strong>中文</strong>
  ·
  <a href="#english">English</a>
</p>

Kindle Paperwhite 1 天气站扩展。它会把上海天气、未来 8 小时逐小时预报、未来 3 天预报渲染成灰阶 `weather.png`，并显示在 Kindle E Ink 屏幕上。

### PNG 样例图

![Kindle PW1 Weather Station sample](weather.png)

### KUAL 菜单样例

```text
Weather Clock
├─ Update Once
├─ Install 4h Schedule
└─ Remove Schedule
```

### 功能

- 当前天气、温度、湿度、日期、时间与电池百分比
- 未来 8 小时逐小时显示，并显示未来 3 天天气
- 可在 `config.xml` 选择中文或英文显示
- 使用 Open-Meteo 小时预报，不需要 API key
- 只在更新时开启 Wi-Fi，完成后自动关闭
- 单次更新完成后 `worker.sh` 会退出，让 Kindle 可以休眠
- 可安装低耗电 4 小时定时更新

### 文件

- `render.py` - 获取 Open-Meteo 数据、读取电池百分比，并生成 `weather.png`
- `worker.sh` - 执行一次 Wi-Fi、天气、E Ink 更新，然后退出
- `start.sh` - 手动更新一次
- `schedule.sh` - 启动内建低耗电 4 小时定时，并立即更新一次
- `unschedule.sh` - 移除定时，并恢复省电设置
- `config.xml` - KUAL 扩展信息与天气设置
- `menu.json` - KUAL 菜单配置
- `font.ttc` - CJK/天气文字渲染字体
- `weather.png` - 预览用生成图，Kindle 实际运行时会重新生成

### 安装

1. 将项目文件复制到 Kindle：

   ```text
   /mnt/us/extensions/weatheriot
   ```

2. 修改 `config.xml`：

   ```xml
   <city>Shanghai</city>
   <lat>31.2304</lat>
   <lon>121.4737</lon>
   <lang>zh</lang>
   <interval>14400</interval>
   ```

   `lang` 控制图片显示语言：

   - `zh` - 中文
   - `en` - 英文

   `interval` 单位是秒，`14400` 表示 4 小时。

3. 在 KUAL 打开 `Weather Clock`，选择：

   - `Update Once` - 立即更新一次
   - `Install 4h Schedule` - 立即更新并安装每 4 小时定时更新
   - `Remove Schedule` - 停止自动更新

### 需求

- 已越狱 Kindle Paperwhite 1
- KUAL
- Kindle 上的 Python 3
- Python packages: `requests`, `Pillow`
- 不需要天气 API key

### 注意事项

- `weather.png` 是预览用生成图片；Kindle 实际运行时会覆盖它。
- Kindle 需要下载这些文件到 `/mnt/us/extensions/weatheriot`：
  - `config.xml`
  - `font.ttc`
  - `menu.json`
  - `render.py`
  - `schedule.sh`
  - `start.sh`
  - `unschedule.sh`
  - `worker.sh`
  - `weather.png` 可选，只是首次显示前的预览图
- `weather.tmp.png`、`log.txt` 与运行诊断文件应留在本机，不提交到 GitHub。
- `worker.sh` 不会常驻；每次更新后会关 Wi-Fi、恢复 `preventScreenSaver`，然后退出。
- `Install 4h Schedule` 会启动 `schedule.sh` 内建循环，并先立即更新一次；不需要 `crontab`。

---

## English

<p align="center">
  <a href="#中文">中文</a>
  ·
  <strong>English</strong>
</p>

Kindle Paperwhite 1 weather station extension. It renders Shanghai weather, the next 8 hourly forecasts, and the next 3 days to a grayscale `weather.png`, then displays it on the Kindle E Ink screen.

### PNG Sample

![Kindle PW1 Weather Station sample](weather.png)

### KUAL Menu Sample

```text
Weather Clock
├─ Update Once
├─ Install 4h Schedule
└─ Remove Schedule
```

### Features

- Current weather, temperature, humidity, date, time, and battery percentage
- Next 8 hours with one row per hour, plus next 3 days
- Chinese or English display selected from `config.xml`
- Open-Meteo hourly forecast, no API key required
- Wi-Fi turns on only during refresh, then turns off again
- Single-shot `worker.sh` exits after each refresh so Kindle can sleep
- Optional cron schedule for low-power 4-hour refreshes

### Files

- `render.py` - Fetches Open-Meteo data, reads battery percentage, and renders `weather.png`
- `worker.sh` - Runs one Wi-Fi/weather/E Ink refresh, then exits
- `start.sh` - Runs one manual refresh
- `schedule.sh` - Starts the built-in low-power 4-hour schedule and runs one immediate refresh
- `unschedule.sh` - Removes the schedule and restores low-power settings
- `config.xml` - KUAL extension metadata and weather settings
- `menu.json` - KUAL menu configuration
- `font.ttc` - Font used for CJK/weather text rendering
- `weather.png` - Generated preview image; Kindle will regenerate it at runtime

### Setup

1. Copy the project files to Kindle:

   ```text
   /mnt/us/extensions/weatheriot
   ```

2. Edit `config.xml`:

   ```xml
   <city>Shanghai</city>
   <lat>31.2304</lat>
   <lon>121.4737</lon>
   <lang>zh</lang>
   <interval>14400</interval>
   ```

   `lang` controls the rendered display language:

   - `zh` - Chinese
   - `en` - English

   `interval` is in seconds. `14400` means 4 hours.

3. From KUAL, open `Weather Clock` and choose:

   - `Update Once` - refresh immediately
   - `Install 4h Schedule` - refresh now and then every 4 hours
   - `Remove Schedule` - stop automatic refreshes

### Requirements

- Jailbroken Kindle Paperwhite 1
- KUAL
- Python 3 on Kindle
- Python packages: `requests`, `Pillow`
- No weather API key is required

### Notes

- `weather.png` is included as a generated preview image. Runtime updates will overwrite it on Kindle.
- Download these files to `/mnt/us/extensions/weatheriot` on Kindle:
  - `config.xml`
  - `font.ttc`
  - `menu.json`
  - `render.py`
  - `schedule.sh`
  - `start.sh`
  - `unschedule.sh`
  - `worker.sh`
  - `weather.png` is optional; it is only the preview image before the first refresh
- `weather.tmp.png`, `log.txt`, and runtime diagnostics should stay local.
- `worker.sh` does not stay resident. It turns Wi-Fi off, restores `preventScreenSaver`, updates the image, and exits after each run.
- `Install 4h Schedule` starts the built-in `schedule.sh` loop and runs one immediate refresh first; `crontab` is not required.
