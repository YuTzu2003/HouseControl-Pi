import json
import logging
import os
import shutil
import subprocess
import sys
import threading
from pathlib import Path
from urllib.parse import parse_qs, urlparse

TOPIC_PLAY = "house/music/play"
TOPIC_STOP = "house/music/stop"
TOPIC_STATE = "house/music/state"
LOGGER = logging.getLogger(__name__)
ALLOWED_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}
AUDIO_DEVICE = os.environ.get("HOUSE_CONTROL_AUDIO_DEVICE", "auto").strip()

def _find_ytdlp():
    for name in ("yt-dlp", "youtube-dl"):
        venv_path = Path(sys.executable).with_name(name)
        if venv_path.is_file() and os.access(venv_path, os.X_OK):
            return str(venv_path)
    for name in ("yt-dlp", "youtube-dl"):
        path = shutil.which(name)
        if path:
            return path
    return None


def _single_video_url(url, parsed):
    if parsed.hostname and parsed.hostname.lower().rstrip(".") in {"youtube.com", "www.youtube.com", "m.youtube.com"} and parsed.path == "/watch":
        video_id = parse_qs(parsed.query).get("v", [""])[0]
        if video_id:
            return f"https://www.youtube.com/watch?v={video_id}"
    return url


class MusicService:
    def __init__(self, client):
        self.client = client
        self.process = None
        self._lock = threading.Lock()

    def handle_play(self, payload, retained=False):
        if retained or len(payload) > 2048:
            return
        try:
            ok, error = self.play_url(json.loads(payload.decode("utf-8"))["url"])
            if ok:
                print("音樂播放指令已啟動")
            else:
                LOGGER.error("音樂播放失敗：%s", error)
        except (KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError, FileNotFoundError) as error:
            LOGGER.exception("音樂播放指令格式錯誤")
            self.publish({"state": "error", "message": str(error)})

    def play_url(self, url):
        if not isinstance(url, str) or not url.strip():
            return self._fail("請提供 YouTube 影片連結")
        url = url.strip()
        parsed = urlparse(url)
        host = (parsed.hostname or "").lower().rstrip(".")
        if parsed.scheme not in {"http", "https"} or host not in ALLOWED_HOSTS:
            return self._fail("請提供 youtube.com 或 youtu.be 的連結")
        url = _single_video_url(url, parsed)
        mpv_path = shutil.which("mpv")
        ytdlp_path = _find_ytdlp()
        if not mpv_path:
            return self._fail("樹莓派找不到 mpv，請先安裝：sudo apt install mpv")
        if not ytdlp_path:
            return self._fail("樹莓派找不到 yt-dlp，請先執行 uv sync 或安裝 yt-dlp")
        try:
            self.stop()
            command = [
                mpv_path,
                "--no-video",
                "--force-window=no",
                "--no-terminal",
                "--msg-level=all=warn",
                "--ytdl-format=bestaudio/best",
            ]
            if AUDIO_DEVICE and AUDIO_DEVICE != "auto":
                command.append(f"--audio-device={AUDIO_DEVICE}")
            print(f"Music audio device: {AUDIO_DEVICE or 'auto'}")
            command.append(url)
            environment = os.environ.copy()
            # Older Raspberry Pi mpv releases do not support --ytdl-path.
            # Their built-in ytdl hook still resolves yt-dlp from PATH.
            environment["PATH"] = f"{Path(ytdlp_path).parent}{os.pathsep}{environment.get('PATH', '')}"
            process = subprocess.Popen(
                command,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                # The controller's stderr is redirected to logs/controller.log
                # by start_house_control.sh, so mpv diagnostics remain visible.
                stderr=None,
                env=environment,
            )
            with self._lock:
                self.process = process
            threading.Thread(target=self._watch, args=(process, url), daemon=True).start()
        except (FileNotFoundError, OSError) as error:
            with self._lock:
                self.process = None
            return self._fail(str(error))
        self.publish({"state": "playing", "url": url})
        return True, None

    def handle_stop(self, payload, retained=False):
        if not retained:
            self.stop()
            self.publish({"state": "stopped"})
            print("音樂停止指令已套用")

    def stop(self):
        with self._lock:
            process = self.process
            self.process = None
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)

    def _watch(self, process, url):
        return_code = process.wait()
        with self._lock:
            if self.process is not process:
                return
            self.process = None
        if return_code == 0:
            self.publish({"state": "stopped", "url": url})
            return
        message = f"mpv 結束（代碼 {return_code}）。請檢查網路、yt-dlp 與喇叭輸出。"
        LOGGER.error("%s URL=%s", message, url)
        self.publish({"state": "error", "url": url, "message": message})

    def _fail(self, message):
        LOGGER.error("%s", message)
        self.publish({"state": "error", "message": message})
        return False, message

    def publish(self, data):
        self.client.publish(TOPIC_STATE, json.dumps(data), qos=1, retain=True)
