# Changelog

All notable changes to this project will be documented in this file.

## 1.5.0 - 2026-07-23

- Changed `worker.sh` from a resident infinite loop to a single-shot refresh process.
- Added `schedule.sh` and `unschedule.sh` for low-power cron-based automatic updates.
- Restored Kindle screensaver permission after each refresh so the device can sleep between updates.
- Shortened Wi-Fi connection waiting and render timeout windows to reduce awake time.
- Changed the default automatic refresh interval to 6 hours.

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
