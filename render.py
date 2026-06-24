#!/usr/bin/python3

import requests
#print("DEBUG 1: Python imports 完成")
from PIL import Image, ImageDraw, ImageFont
import sys
import time
import os
import urllib3
import traceback

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
city = sys.argv[1] if len(sys.argv) > 1 else "Shanghai"
apikey = sys.argv[2] if len(sys.argv) > 2 else "YOUR_API_KEY"

curr_url = f"http://api.openweathermap.org/data/2.5/weather?q={city}&appid={apikey}&units=metric&lang=zh_tw"
fore_url = f"http://api.openweathermap.org/data/2.5/forecast?q={city}&appid={apikey}&units=metric&lang=zh_tw"

def get_weather_icon(desc):
    if "晴" in desc: return "☀"
    if "雲" in desc or "陰" in desc: return "☁"
    if "雨" in desc: return "☂"
    if "雪" in desc: return "❄"
    if "雷" in desc: return "⚡"
    return "·"

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
    "Smoke": "煙霧"
}

def fetch_data(url):
    for i in range(2):
        try:
            r = requests.get(
                url,
                timeout=12,
                verify=False
            )

            if r.status_code == 200:
                return r.json()

        except Exception:
            time.sleep(2)

    return None

try:
    #print("DEBUG 2: 準備抓 weather API")
    c_res = fetch_data(curr_url)
    #print("DEBUG 3: weather API 完成")
    #print("DEBUG 4: 準備抓 forecast API")
    f_res = fetch_data(fore_url)
    #print("DEBUG 5: forecast API 完成")

    if not c_res: raise Exception("無法取得當前天氣 API 數據")

    c_temp = round(c_res["main"]["temp"])
    c_desc = c_res["weather"][0]["description"]
    raw_desc = c_res["weather"][0]["main"]
    c_desc = WEATHER_MAP.get(raw_desc, raw_desc)
    c_hum  = c_res["main"]["humidity"]
    status = "更新成功"

    # 大畫布滿版排版 (758x1024)
    W, H = 758, 1024
    #print("DEBUG 6: 開始產生圖片")
    img = Image.new("L", (W, H), 240)
    draw = ImageDraw.Draw(img)

    def get_font(size):
        p = os.path.join(BASE_DIR, "font.ttc")
        if not os.path.exists(p): p = "/usr/java/lib/fonts/CJK.ttf"
        return ImageFont.truetype(p, size)

    f_v_big = get_font(135)
    f_big   = get_font(115)
    f_mid   = get_font(54)
    f_small = get_font(38)

    # 恢復最原始、絕對安全的 time 呼叫
    draw.text((45, 50), city.upper(), font=f_mid, fill=20)
    draw.text((45, 120), time.strftime("%Y/%m/%d %a"), font=f_small, fill=20)
    
    time_str = time.strftime("%H:%M")
    try:
        t_w = f_mid.getlength(time_str)
        draw.text((W - t_w - 45, 50), time_str, font=f_mid, fill=20)
    except:
        draw.text((560, 50), time_str, font=f_mid, fill=20)

    draw.text((65, 210), get_weather_icon(c_desc), font=f_big, fill=20)
    draw.text((270, 185), f"{c_temp}°C", font=f_v_big, fill=20)
    draw.text((275, 350), f"{c_desc} | 濕度 {c_hum}%", font=f_small, fill=20)
    
    draw.line((45, 440, 713, 440), fill=90, width=8)
    draw.text((45, 465), "未來五日預報", font=f_small, fill=50)

    if not f_res: raise Exception("無法取得未來天氣 API 數據")
    if f_res and "list" in f_res:
        y = 540
        for item in f_res["list"][::8][:5]:
            d_time = item["dt_txt"][5:10].replace("-", "/")
            d_temp = f"{round(item['main']['temp'])}°C"
            raw_desc = item["weather"][0]["main"]
            d_desc = WEATHER_MAP.get(raw_desc, raw_desc)
            
            draw.text((60, y), d_time, font=f_small, fill=50)
            draw.text((210, y), get_weather_icon(d_desc), font=f_small, fill=50)
            draw.text((330, y), d_desc, font=f_small, fill=50)
            try:
                tmp_w = f_small.getlength(d_temp)
                draw.text((W - tmp_w - 60, y), d_temp, font=f_small, fill=50)
            except:
                draw.text((620, y), d_temp, font=f_small, fill=50)
            y += 85


    draw.text((45, 960), f"上海站 {status}：{time.strftime('%H:%M')}", font=f_small, fill=20)

    # ==================================================
    # PW1 最佳化輸出
    # ==================================================

    # 8-bit grayscale
    final_img = img.point(lambda x: 0 if x < 128 else 255, 'L')

    target_dir = "/mnt/us/extensions/weatheriot"
    base_path = os.path.join(target_dir, "weather.png")

    # 刪除舊圖
    if os.path.exists(base_path):
        os.remove(base_path)

    # 最佳化 PNG
    #print("DEBUG 7: 開始儲存 PNG")
    final_img.save(
        base_path,
        "PNG",
        optimize=True
    )

    # 強制寫入磁碟
    if hasattr(os, 'sync'):
        os.sync()

    # 強制回收
    import gc
    gc.collect()

    #print("DEBUG 8: render.py 完成")
    # 強制退出
    import sys
    sys.exit(0)

except Exception:

    print("FATAL ERROR 發生：")

    traceback.print_exc()

    os._exit(1)