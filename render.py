#!/usr/bin/python3

import os
import subprocess
import sys
import time
import traceback
from collections import Counter, defaultdict

import requests
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TARGET_DIR = "/mnt/us/extensions/weatheriot"

city = sys.argv[1] if len(sys.argv) > 1 else "Shanghai"
apikey = sys.argv[2] if len(sys.argv) > 2 else "YOUR_API_KEY"

FORECAST_URL = (
    "http://api.openweathermap.org/data/2.5/forecast"
    f"?q={city}&appid={apikey}&units=metric&lang=zh_tw"
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


def fetch_forecast():
    session = requests.Session()
    for _ in range(2):
        try:
            r = session.get(FORECAST_URL, timeout=12)
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


def build_day_summaries(items, limit=3):
    today = time.strftime("%Y-%m-%d")
    grouped = defaultdict(list)

    for item in items:
        day = item["dt_txt"][:10]
        if day > today:
            grouped[day].append(item)

    summaries = []
    for day in sorted(grouped.keys())[:limit]:
        rows = grouped[day]
        temps = [row["main"]["temp"] for row in rows]
        descs = [map_desc(row) for row in rows]
        desc = Counter(descs).most_common(1)[0][0]
        summaries.append(
            {
                "date": day[5:].replace("-", "/"),
                "desc": desc,
                "min": round(min(temps)),
                "max": round(max(temps)),
            }
        )

    return summaries


def save_optimized(img):
    final_img = img.point(lambda x: 0 if x < 128 else 255, "L")
    base_path = os.path.join(TARGET_DIR, "weather.png")
    tmp_path = os.path.join(TARGET_DIR, "weather.tmp.png")

    if not os.path.exists(TARGET_DIR):
        os.makedirs(TARGET_DIR)

    final_img.save(tmp_path, "PNG", optimize=False)
    os.replace(tmp_path, base_path)


try:
    forecast = fetch_forecast()
    if not forecast or "list" not in forecast or not forecast["list"]:
        raise Exception("無法取得天氣預報 API 數據")

    items = forecast["list"]
    now_item = items[0]
    now_desc = map_desc(now_item)
    now_temp = round(now_item["main"]["temp"])
    now_hum = now_item["main"].get("humidity", "--")
    battery = get_battery_percent()

    cutoff_ts = time.time() + 8 * 3600
    hourly = [item for item in items if item.get("dt", 0) <= cutoff_ts][:3]
    if len(hourly) < 3:
        hourly = items[:3]
    days = build_day_summaries(items, 3)

    W, H = 758, 1024
    img = Image.new("L", (W, H), 240)
    draw = ImageDraw.Draw(img)

    f_huge = get_font(112)
    f_big = get_font(78)
    f_mid = get_font(48)
    f_small = get_font(34)
    f_tiny = get_font(28)

    # Header
    draw.text((45, 40), city.upper(), font=f_mid, fill=20)
    draw.text((45, 100), time.strftime("%Y/%m/%d %a"), font=f_tiny, fill=20)
    right_text(draw, W - 45, 40, time.strftime("%H:%M"), f_mid, 20)
    right_text(draw, W - 45, 100, f"電量 {battery}", f_tiny, 20)

    # Current / nearest forecast
    draw.text((55, 175), get_weather_icon(now_desc), font=f_big, fill=20)
    draw.text((205, 150), f"{now_temp}°C", font=f_huge, fill=20)
    draw.text((215, 295), f"{now_desc} | 濕度 {now_hum}%", font=f_small, fill=20)

    draw.line((45, 375, 713, 375), fill=80, width=6)

    # Next 8 hours. OpenWeather 3-hour forecast gives the closest three slots.
    draw.text((45, 400), "未來八小時", font=f_small, fill=50)
    y = 455
    for item in hourly:
        hour = item["dt_txt"][11:16]
        desc = map_desc(item)
        temp = f"{round(item['main']['temp'])}°C"
        hum = f"{item['main'].get('humidity', '--')}%"
        draw.text((60, y), hour, font=f_small, fill=20)
        draw.text((190, y), get_weather_icon(desc), font=f_small, fill=20)
        draw.text((280, y), desc, font=f_small, fill=20)
        right_text(draw, 610, y, temp, f_small, 20)
        right_text(draw, 705, y + 4, hum, f_tiny, 50)
        y += 74

    draw.line((45, 690, 713, 690), fill=80, width=6)

    # Next 3 days
    draw.text((45, 715), "未來三天", font=f_small, fill=50)
    y = 770
    for day in days:
        temp_range = f"{day['min']}~{day['max']}°C"
        draw.text((60, y), day["date"], font=f_small, fill=20)
        draw.text((190, y), get_weather_icon(day["desc"]), font=f_small, fill=20)
        draw.text((280, y), day["desc"], font=f_small, fill=20)
        right_text(draw, 705, y, temp_range, f_small, 20)
        y += 68

    draw.text(
        (45, 960),
        f"更新成功：{time.strftime('%H:%M')} | 單次預報 API",
        font=f_tiny,
        fill=20,
    )

    save_optimized(img)
    sys.exit(0)

except Exception:
    print("FATAL ERROR 發生：")
    traceback.print_exc()
    os._exit(1)
