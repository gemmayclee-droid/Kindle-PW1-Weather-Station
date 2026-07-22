# Kindle PW1 Weather Station

A Kindle Paperwhite 1 weather-station extension that renders Shanghai weather, the next 8 hourly forecasts, and the next 3 days to a grayscale `weather.png`, then displays it on the Kindle E Ink screen.

## Features

- Nearby weather, temperature, humidity, date, time, and battery percentage
- Next 8 hours with one row per hour, plus next 3 days, optimized for 758x1024 Kindle PW1 display
- OpenWeatherMap API support
- Wi-Fi on only during refresh, then off again to reduce power usage
- Single OpenWeatherMap One Call API request per refresh to reduce network time
- Periodic E Ink refresh with less frequent full refresh to reduce ghosting and power use
- KUAL menu entries for starting the weather clock and running an environment scan

## Files

- `render.py` - Fetches One Call hourly/daily data, reads Kindle battery percentage, and renders `weather.png`
- `worker.sh` - Main loop for Wi-Fi, rendering, display refresh, and low-power sleep interval
- `start.sh` - Starts the worker process
- `scan.sh` - Writes Kindle environment diagnostics
- `config.xml` - Extension metadata and settings
- `menu.json` - KUAL menu configuration
- `font.ttc` - Font used for CJK/weather text rendering
- `weather.png` - Example rendered output

## Setup

1. Copy the project files to:

   ```text
   /mnt/us/extensions/weatheriot
   ```

2. Edit `config.xml` and set your city and OpenWeatherMap API key:

   ```xml
   <city>Shanghai</city>
   <lat>31.2304</lat>
   <lon>121.4737</lon>
   <apikey>YOUR_API_KEY</apikey>
   ```

3. From KUAL, open `Weather Clock` and choose `Start Weather Clock`.

## Requirements

- Jailbroken Kindle Paperwhite 1
- KUAL
- Python 3 on Kindle
- Python packages:
  - `requests`
  - `Pillow`
- OpenWeatherMap API key

## Notes

- Do not commit a real API key to the repository.
- `log.txt` and runtime diagnostics should stay local.
- The default refresh loop in `worker.sh` sleeps for 4 hours between updates.
- Battery percentage is shown under the time. If the battery value cannot be read, it displays `電量 --%`.
- The 8-hour view uses OpenWeatherMap One Call `hourly` data, so it shows one row per hour.
