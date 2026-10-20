# Changelog

All notable changes to this project will be documented in this file.

## Unreleased - 2026-10-19

- 繁中：兩個 KUAL 選單新增排程狀態，並隱藏當前不適用的啟用／停用按鈕；另外提示舊排程 PID。
- 简中：两个 KUAL 菜单新增定时状态，并隐藏当前不适用的启用／停用按钮；另外提示旧定时 PID。
- English: Show schedule status in both KUAL menus, hide inapplicable enable/disable actions, and flag legacy schedule PID files.

- 繁中：統一兩個 KUAL 選單的省電排程入口，移除舊四小時排程按鈕；啟用或停用時自動清理舊排程，並同步三語 README。
- 简中：统一两个 KUAL 菜单的省电定时入口，移除旧四小时定时按钮；启用或停用时自动清理旧定时，并同步三语 README。
- English: Unify both KUAL schedule controls, remove the legacy four-hour button, clean up legacy scheduling when enabling or disabling, and update all three README languages.

- 繁中：排程更新時從螢幕保護完整喚醒，完成後恢復休眠；繪圖上限調整為 180 秒，整輪上限 420 秒。手動與排程更新使用互斥鎖避免互相關閉 Wi-Fi，手動更新保留歷史日誌。
- 简中：定时更新时从屏幕保护完整唤醒，完成后恢复休眠；绘图上限调整为 180 秒，整轮上限 420 秒。手动与定时更新使用互斥锁避免互相关闭 Wi-Fi，手动更新保留历史日志。
- English: Fully wake from Screen Saver for scheduled updates and restore sleep afterward. Allow 180 seconds for rendering and 420 seconds per update. Serialize manual and scheduled workers to prevent Wi-Fi conflicts, and retain manual-update log history.

## 1.20.0 - 2026-09-03

- Replaced the rolling 4-hour schedule with fixed weekday refreshes at 08:00, 12:00, 16:00, and 20:00.
- After 20:00, the scheduler waits until 08:00 on the next weekday; Friday evening waits until Monday morning.
- Removed the unused configurable interval setting.

## 1.19.0 - 2026-08-31

- Removed the night sleep window because Kindle system sleep freezes the background scheduler and prevents later weather refreshes.
- Automatic updates now keep the Kindle awake so the 4-hour scheduler can reliably run; Wi-Fi and the frontlight still turn off after each refresh.
- Updated the documentation to explain this Kindle power-management limitation.

## 1.18.0 - 2026-08-20

- Added a configurable night power-save window with default hours from 22:00 to 07:00.
- Restored Kindle screensaver and sleep permission after successful night refreshes to reduce overnight battery drain.
- Changed the 4-hour scheduler to skip weather updates during the night sleep window, avoiding unnecessary Wi-Fi and render work.

## 1.17.0 - 2026-08-18

- Changed the README default language section to Traditional Chinese.
- Reordered README language navigation to show Traditional Chinese first.

## 1.16.0 - 2026-08-18

- Added a Traditional Chinese README section.
- Updated README language navigation to include Simplified Chinese, Traditional Chinese, and English.

## 1.15.0 - 2026-08-03

- Kept `preventScreenSaver` enabled after a successful refresh so `weather.png` remains visible.
- Continued turning Wi-Fi off after each refresh to avoid unnecessary network power use.
- Left `unschedule.sh` responsible for restoring the normal screensaver behavior when automatic updates are removed.

## 1.14.0 - 2026-07-23

- Restored `worker.sh` as a single-shot refresh script so manual updates remain reliable.
- Changed `schedule.sh` to own the 4-hour background loop and call `worker.sh` once per cycle.
- Made `Install 4h Schedule` start the first refresh immediately, then sleep for the configured interval.
- Added clearer worker logging for version, render timing, image size before and after rendering, and cleanup state.
- Kept Wi-Fi and `preventScreenSaver` enabled only during the refresh cycle.

## 1.13.0 - 2026-07-23

- Merged the scheduling loop into `schedule.sh` and removed `scheduler.sh`.
- Added a `schedule.pid` file so `unschedule.sh` can stop the built-in scheduler cleanly.
- Updated README with the exact files to copy to Kindle.

## 1.12.0 - 2026-07-23

- Removed the `crontab` dependency from `schedule.sh`.
- Changed `schedule.sh` to run one foreground refresh immediately, then start `scheduler.sh` for future updates.
- Changed `scheduler.sh` to support sleeping first, preserving the proven 4-hour loop scheduling model with single-shot `worker.sh` refreshes.

## 1.11.0 - 2026-07-23

- Added `scheduler.sh` fallback for Kindle systems without `crontab`.
- Changed `schedule.sh` to stop old workers, install the best available scheduler, and run the first refresh in the foreground.
- Changed `worker.sh` to attempt the HTTPS weather fetch even when ping-based Wi-Fi checks fail.
- Updated README with the no-crontab fallback behavior.

## 1.10.0 - 2026-07-23

- Added KUAL menu samples to both README language sections.

## 1.9.0 - 2026-07-23

- Reworked README language switching into a GitHub-compatible tab navigation layout.
- Kept Chinese as the default first section while preserving the English section and sample image.

## 1.8.0 - 2026-07-23

- Reworked README into Chinese-first and English collapsible sections.
- Added the generated `weather.png` sample image display to both README language sections.

## 1.7.0 - 2026-07-23

- Added `<lang>` setting to `config.xml` for Chinese or English rendering.
- Added bilingual weather labels and WMO weather descriptions to `render.py`.
- Updated `worker.sh` to pass the configured language to `render.py`.
- Reintroduced a generated `weather.png` preview image.
- Expanded README with Chinese and English instructions.

## 1.6.0 - 2026-07-23

- Removed unused OpenWeatherMap API key and unit settings from `config.xml`.
- Removed unused API key argument handling from `worker.sh` and `render.py`.
- Removed the committed generated `weather.png` example from the repository.
- Removed the diagnostic scan script and KUAL menu entry.
- Added generated weather images to `.gitignore`.

## 1.5.0 - 2026-07-23

- Changed `worker.sh` from a resident infinite loop to a single-shot refresh process.
- Added `schedule.sh` and `unschedule.sh` for low-power cron-based automatic updates.
- Restored Kindle screensaver permission after each refresh so the device can sleep between updates.
- Shortened Wi-Fi connection waiting and render timeout windows to reduce awake time.
- Changed the default automatic refresh interval to 4 hours.

## 1.4.0 - 2026-07-22

- Switched hourly rendering from OpenWeatherMap One Call to Open-Meteo hourly forecast data.
- Removed the runtime dependency on One Call API access for the 8-hour view.
- Added clearer API failure logging for forecast fetch errors.

## 1.3.0 - 2026-07-22

- Switched the 8-hour weather view to true hourly data using OpenWeatherMap One Call.
- Added Shanghai latitude and longitude settings to `config.xml`.
- Updated `worker.sh` to pass latitude and longitude to `render.py`.
- Updated documentation to clarify that the 8-hour view shows one row per hour.

## 1.2.0 - 2026-07-22

- Changed the weather layout to show the next 8 hours and next 3 days.
- Reduced weather fetching to a single OpenWeatherMap forecast API call per refresh.
- Extended the default refresh interval from 3 hours to 4 hours.
- Reduced full E Ink refresh frequency from every 3 updates to every 6 updates.
- Avoided unnecessary process cleanup and removed forced disk sync from rendering.

## 1.1.0 - 2026-06-24

- Added Kindle battery percentage display to the weather render.
- Added fallback battery detection through common Linux power-supply paths and `lipc-get-prop`.
- Documented the battery display behavior in the README.

## 1.0.0 - 2026-06-24

- Added initial Kindle PW1 weather-station extension.
- Added weather image rendering with OpenWeatherMap current weather and forecast data.
- Added KUAL menu configuration.
- Added startup, worker, and environment scan scripts.
- Added CJK font asset and sample rendered `weather.png`.
- Replaced the committed API key value with `YOUR_API_KEY` for safe public publishing.
