# Changelog

All notable changes to this project will be documented in this file.

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
