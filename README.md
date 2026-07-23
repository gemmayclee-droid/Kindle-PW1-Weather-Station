# Kindle PW1 Weather Station

A Kindle Paperwhite 1 weather-station extension that renders Shanghai weather, the next 8 hourly forecasts, and the next 3 days to a grayscale `weather.png`, then displays it on the Kindle E Ink screen.

## Features

- Nearby weather, temperature, humidity, date, time, and battery percentage
- Next 8 hours with one row per hour, plus next 3 days, optimized for 758x1024 Kindle PW1 display
- Open-Meteo hourly forecast support
- Wi-Fi on only during refresh, then off again to reduce power usage
- Single Open-Meteo forecast request per refresh to reduce network time
- Single-shot worker that exits after each refresh so Kindle can sleep between updates
- Optional cron schedule for low-power 4-hour refreshes
- KUAL menu entries for manual refresh and schedule control

## Files

- `render.py` - Fetches Open-Meteo hourly/daily data, reads Kindle battery percentage, and renders `weather.png`
- `worker.sh` - Runs one Wi-Fi/weather/E Ink refresh, then exits
- `start.sh` - Runs one manual refresh
- `schedule.sh` - Installs the low-power cron schedule and runs one immediate refresh
- `unschedule.sh` - Removes the cron schedule and restores low-power settings
- `config.xml` - Extension metadata and settings
- `menu.json` - KUAL menu configuration
- `font.ttc` - Font used for CJK/weather text rendering

## Setup

1. Copy the project files to:

   ```text
   /mnt/us/extensions/weatheriot
   ```

2. Edit `config.xml` and set your city and coordinates:

   ```xml
   <city>Shanghai</city>
   <lat>31.2304</lat>
   <lon>121.4737</lon>
   <interval>14400</interval>
   ```

3. From KUAL, open `Weather Clock` and choose:

   - `Update Once` to refresh immediately.
   - `Install 4h Schedule` to refresh now and then every 4 hours.
   - `Remove Schedule` to stop automatic refreshes.

## Requirements

- Jailbroken Kindle Paperwhite 1
- KUAL
- Python 3 on Kindle
- Python packages:
  - `requests`
  - `Pillow`
- No weather API key is required for the current Open-Meteo renderer.

## Notes

- Generated `weather.png`, `weather.tmp.png`, `log.txt`, and runtime diagnostics should stay local.
- The default automatic schedule refreshes every 4 hours. Change `<interval>` in `config.xml` if you want a different interval.
- `worker.sh` does not stay resident. It turns Wi-Fi off, restores `preventScreenSaver`, updates the image, and exits after each run.
- Battery percentage is shown under the time. If the battery value cannot be read, it displays `電量 --%`.
- The 8-hour view uses Open-Meteo `hourly` data, so it shows one row per hour without requiring One Call API access.
