# Changelog

All notable changes to this project will be documented in this file.

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
