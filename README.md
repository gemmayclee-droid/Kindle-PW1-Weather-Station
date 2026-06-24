# Kindle PW1 Weather Station

A Kindle Paperwhite 1 weather-station extension that renders current weather and a five-day forecast to a grayscale `weather.png`, then displays it on the Kindle E Ink screen.

## Features

- Current weather, temperature, humidity, date, and time
- Five-day forecast layout optimized for 758x1024 Kindle PW1 display
- OpenWeatherMap API support
- Wi-Fi on only during refresh, then off again to reduce power usage
- Periodic E Ink refresh with occasional full refresh to reduce ghosting
- KUAL menu entries for starting the weather clock and running an environment scan

## Files

- `render.py` - Fetches weather data and renders `weather.png`
- `worker.sh` - Main loop for Wi-Fi, rendering, display refresh, and sleep interval
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
- The default refresh loop in `worker.sh` sleeps for 3 hours between updates.
