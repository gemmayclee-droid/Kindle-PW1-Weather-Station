#!/usr/bin/python3

import os
import subprocess
import sys
import time
import traceback

import requests
import urllib3
from PIL import Image, ImageDraw, ImageFont

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_DIR = "/mnt/us/extensions/weatheriot"

city = sys.argv[1] if len(sys.argv) > 1 else "Shanghai"
lat = sys.argv[2] if len(sys.argv) > 2 else "31.2304"
lon = sys.argv[3] if len(sys.argv) > 3 else "121.4737"

OPEN_METEO_URL = (
    "https://api.open-meteo.com/v1/forecast"
    f"?latitude={lat}&longitude={lon}"
    "&current=temperature_2m,relative_humidity_2m,weather_code"
    "&hourly=temperature_2m,relative_humidity_2m,weather_code"
    "&daily=weather_code,temperature_2m_max,temperature_2m_min"
    "&timezone=Asia%2FShanghai&forecast_days=4"
)

WMO_MAP = {
    0: "晴天",
    1: "晴天",
    2: "多雲",
    3: "陰天",
    45: "霧",
    48: "霧",
    51: "毛雨",
    53: "毛雨",
    55: "毛雨",
    56: "凍雨",
    57: "凍雨",
    61: "下雨",
    63: "下雨",
    65: "大雨",
    66: "凍雨",
    67: "凍雨",
    71: "下雪",
    73: "下雪",
    75: "大雪",
    77: "下雪",
    80: "陣雨",
    81: "陣雨",
    82: "大雨",
    85: "陣雪",
    86: "大雪",
    95: "雷雨",
    96: "雷雨",
    99: "雷雨",
}


def get_weather_icon(desc):
    if "晴" in desc:
        return "☀"
    if "雲" in desc or "陰" in desc:
        return "☁"
    if "雨" in desc:
        return "☂"
    if "雪" in desc:
        return "❄"
    if "雷" in desc:
        return "⚡"
    return "·"


def fetch_weather():
    session = requests.Session()
    last_status = None
    last_body = ""

    for _ in range(2):
        try:
            r = session.get(OPEN_METEO_URL, timeout=12, verify=False)
            last_status = r.status_code
            last_body = getattr(r, "text", "")[:160]
            if r.status_code == 200:
                return r.json()
        except Exception as exc:
            last_body = str(exc)
            time.sleep(2)

    raise Exception(f"Open-Meteo API 失敗 status={last_status} body={last_body}")


def get_battery_percent():
    battery_paths = [
        "/sys/class/power_supply/max17042_battery/capacity",
        "/sys/class/power_supply/battery/capacity",
        "/sys/class/power_supply/BAT0/capacity",
    ]

    for path in battery_paths:
        try:
            with open(path, "r") as f:
                value = f.read().strip()
            if value.isdigit():
                return f"{int(value)}%"
        except Exception:
            pass

    try:
        value = subprocess.check_output(
            ["lipc-get-prop", "com.lab126.powerd", "battLevel"],
            stderr=subprocess.DEVNULL,
            timeout=3,
            text=True,
        ).strip()
        if value.isdigit():
            return f"{int(value)}%"
    except Exception:
        pass

    return "--%"


def map_code(code):
    try:
        return WMO_MAP.get(int(code), "未知")
    except Exception:
        return "未知"


def get_font(size):
    path = os.path.join(BASE_DIR, "font.ttc")
    if not os.path.exists(path):
        path = "/usr/java/lib/fonts/CJK.ttf"
    return ImageFont.truetype(path, size)


def text_width(font, value):
    try:
        return font.getlength(value)
    except Exception:
        return font.getbbox(value)[2]


def right_text(draw, x_right, y, text, font, fill):
    draw.text((x_right - text_width(font, text), y), text, font=font, fill=fill)


def save_optimized(img):
    final_img = img.point(lambda x: 0 if x < 128 else 255, "L")
    base_path = os.path.join(TARGET_DIR, "weather.png")
    tmp_path = os.path.join(TARGET_DIR, "weather.tmp.png")

    if not os.path.exists(TARGET_DIR):
        os.makedirs(TARGET_DIR)

    final_img.save(tmp_path, "PNG", optimize=False)
    os.replace(tmp_path, base_path)


def build_hourly_rows(weather):
    hourly = weather.get("hourly", {})
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    humidity = hourly.get("relative_humidity_2m", [])
    codes = hourly.get("weather_code", [])

    current_time = weather.get("current", {}).get("time")
    if not current_time:
        current_time = time.strftime("%Y-%m-%dT%H:00")

    rows = []
    for i, t in enumerate(times):
        if t <= current_time:
            continue
        try:
            rows.append(
                {
                    "time": t[11:16],
                    "temp": round(temps[i]),
                    "humidity": humidity[i],
                    "desc": map_code(codes[i]),
                }
            )
        except Exception:
            continue
        if len(rows) >= 8:
            break

    return rows


def build_daily_rows(weather):
    daily = weather.get("daily", {})
    times = daily.get("time", [])[1:4]
    codes = daily.get("weather_code", [])[1:4]
    temp_max = daily.get("temperature_2m_max", [])[1:4]
    temp_min = daily.get("temperature_2m_min", [])[1:4]

    rows = []
    for i, day in enumerate(times):
        try:
            rows.append(
                {
                    "date": day[5:].replace("-", "/"),
                    "desc": map_code(codes[i]),
                    "min": round(temp_min[i]),
                    "max": round(temp_max[i]),
                }
            )
        except Exception:
            continue

    return rows


try:
    weather = fetch_weather()
    if not weather or "hourly" not in weather:
        raise Exception("無法取得逐小時天氣 API 數據")

    current = weather.get("current", {})
    current_desc = map_code(current.get("weather_code"))
    current_temp = round(current.get("temperature_2m", 0))
    current_hum = current.get("relative_humidity_2m", "--")
    battery = get_battery_percent()

    hourly_rows = build_hourly_rows(weather)
    daily_rows = build_daily_rows(weather)

    if len(hourly_rows) < 8:
        raise Exception(f"逐小時天氣資料不足 8 筆，實際 {len(hourly_rows)} 筆")

    W, H = 758, 1024
    img = Image.new("L", (W, H), 240)
    draw = ImageDraw.Draw(img)

    f_huge = get_font(108)
    f_big = get_font(72)
    f_mid = get_font(46)
    f_small = get_font(31)
    f_tiny = get_font(25)

    # Header
    draw.text((45, 36), city.upper(), font=f_mid, fill=20)
    draw.text((45, 92), time.strftime("%Y/%m/%d %a"), font=f_tiny, fill=20)
    right_text(draw, W - 45, 36, time.strftime("%H:%M"), f_mid, 20)
    right_text(draw, W - 45, 92, f"電量 {battery}", f_tiny, 20)

    # Current weather
    draw.text((55, 158), get_weather_icon(current_desc), font=f_big, fill=20)
    draw.text((205, 132), f"{current_temp}°C", font=f_huge, fill=20)
    draw.text((215, 270), f"{current_desc} | 濕度 {current_hum}%", font=f_small, fill=20)

    draw.line((45, 335, 713, 335), fill=80, width=5)

    # Next 8 hours, one row per hour.
    draw.text((45, 358), "未來八小時", font=f_small, fill=50)
    y = 405
    for item in hourly_rows:
        draw.text((55, y), item["time"], font=f_tiny, fill=20)
        draw.text((155, y - 3), get_weather_icon(item["desc"]), font=f_small, fill=20)
        draw.text((225, y), item["desc"], font=f_tiny, fill=20)
        right_text(draw, 610, y, f"{item['temp']}°C", f_tiny, 20)
        right_text(draw, 705, y, f"{item['humidity']}%", f_tiny, 50)
        y += 36

    draw.line((45, 710, 713, 710), fill=80, width=5)

    # Next 3 days
    draw.text((45, 735), "未來三天", font=f_small, fill=50)
    y = 785
    for day in daily_rows:
        temp_range = f"{day['min']}~{day['max']}°C"
        draw.text((60, y), day["date"], font=f_small, fill=20)
        draw.text((190, y), get_weather_icon(day["desc"]), font=f_small, fill=20)
        draw.text((280, y), day["desc"], font=f_small, fill=20)
        right_text(draw, 705, y, temp_range, f_small, 20)
        y += 62

    draw.text(
        (45, 960),
        f"更新成功：{time.strftime('%H:%M')} | Open-Meteo hourly",
        font=f_tiny,
        fill=20,
    )

    save_optimized(img)
    sys.exit(0)

except Exception:
    print("FATAL ERROR 發生：")
    traceback.print_exc()
    os._exit(1)
