#!/usr/bin/python3

import os
import subprocess
import sys
import time
import traceback

import requests
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_DIR = "/mnt/us/extensions/weatheriot"

city = sys.argv[1] if len(sys.argv) > 1 else "Shanghai"
apikey = sys.argv[2] if len(sys.argv) > 2 else "YOUR_API_KEY"
lat = sys.argv[3] if len(sys.argv) > 3 else "31.2304"
lon = sys.argv[4] if len(sys.argv) > 4 else "121.4737"

ONECALL_URL = (
    "https://api.openweathermap.org/data/3.0/onecall"
    f"?lat={lat}&lon={lon}&appid={apikey}&units=metric&lang=zh_tw"
    "&exclude=minutely,alerts"
)

WEATHER_MAP = {
    "Clear": "晴天",
    "Clouds": "多雲",
    "Rain": "下雨",
    "Drizzle": "毛雨",
    "Thunderstorm": "雷雨",
    "Snow": "下雪",
    "Mist": "霧",
    "Fog": "濃霧",
    "Haze": "霾",
    "Smoke": "煙霧",
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
    for _ in range(2):
        try:
            r = session.get(ONECALL_URL, timeout=12)
            if r.status_code == 200:
                return r.json()
        except Exception:
            time.sleep(2)
    return None


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


def map_desc(item):
    raw_desc = item["weather"][0]["main"]
    return WEATHER_MAP.get(raw_desc, raw_desc)


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


def fmt_time(ts, timezone_offset, fmt="%H:%M"):
    return time.strftime(fmt, time.gmtime(ts + timezone_offset))


def save_optimized(img):
    final_img = img.point(lambda x: 0 if x < 128 else 255, "L")
    base_path = os.path.join(TARGET_DIR, "weather.png")
    tmp_path = os.path.join(TARGET_DIR, "weather.tmp.png")

    if not os.path.exists(TARGET_DIR):
        os.makedirs(TARGET_DIR)

    final_img.save(tmp_path, "PNG", optimize=False)
    os.replace(tmp_path, base_path)


try:
    weather = fetch_weather()
    if not weather or "current" not in weather or "hourly" not in weather:
        raise Exception("無法取得逐小時天氣 API 數據")

    timezone_offset = int(weather.get("timezone_offset", 8 * 3600))
    current = weather["current"]
    hourly = [
        item for item in weather["hourly"]
        if item.get("dt", 0) > current.get("dt", time.time())
    ][:8]
    daily = weather.get("daily", [])[1:4]

    if len(hourly) < 8:
        raise Exception("逐小時天氣資料不足 8 筆")

    now_desc = map_desc(current)
    now_temp = round(current["temp"])
    now_hum = current.get("humidity", "--")
    battery = get_battery_percent()

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
    draw.text((55, 158), get_weather_icon(now_desc), font=f_big, fill=20)
    draw.text((205, 132), f"{now_temp}°C", font=f_huge, fill=20)
    draw.text((215, 270), f"{now_desc} | 濕度 {now_hum}%", font=f_small, fill=20)

    draw.line((45, 335, 713, 335), fill=80, width=5)

    # Next 8 hours, one row per hour.
    draw.text((45, 358), "未來八小時", font=f_small, fill=50)
    y = 405
    for item in hourly:
        hour = fmt_time(item["dt"], timezone_offset)
        desc = map_desc(item)
        temp = f"{round(item['temp'])}°C"
        hum = f"{item.get('humidity', '--')}%"

        draw.text((55, y), hour, font=f_tiny, fill=20)
        draw.text((155, y - 3), get_weather_icon(desc), font=f_small, fill=20)
        draw.text((225, y), desc, font=f_tiny, fill=20)
        right_text(draw, 610, y, temp, f_tiny, 20)
        right_text(draw, 705, y, hum, f_tiny, 50)
        y += 36

    draw.line((45, 710, 713, 710), fill=80, width=5)

    # Next 3 days
    draw.text((45, 735), "未來三天", font=f_small, fill=50)
    y = 785
    for day in daily:
        desc = map_desc(day)
        date = fmt_time(day["dt"], timezone_offset, "%m/%d")
        temp_range = f"{round(day['temp']['min'])}~{round(day['temp']['max'])}°C"
        draw.text((60, y), date, font=f_small, fill=20)
        draw.text((190, y), get_weather_icon(desc), font=f_small, fill=20)
        draw.text((280, y), desc, font=f_small, fill=20)
        right_text(draw, 705, y, temp_range, f_small, 20)
        y += 62

    draw.text(
        (45, 960),
        f"更新成功：{time.strftime('%H:%M')} | One Call hourly",
        font=f_tiny,
        fill=20,
    )

    save_optimized(img)
    sys.exit(0)

except Exception:
    print("FATAL ERROR 發生：")
    traceback.print_exc()
    os._exit(1)
