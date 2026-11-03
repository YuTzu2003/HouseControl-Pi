import json
import subprocess
from urllib.parse import urlparse

TOPIC_PLAY = "house/music/play"
TOPIC_STOP = "house/music/stop"
TOPIC_STATE = "house/music/state"


class MusicService:
    def __init__(self, client):
        self.client = client
        self.process = None

    def handle_play(self, payload, retained=False):
        if retained or len(payload) > 2048:
            return
        try:
            ok, error = self.play_url(json.loads(payload.decode("utf-8"))["url"])
            if not ok:
                self.publish({"state": "error", "message": error})
        except (KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError, FileNotFoundError) as error:
            self.publish({"state": "error", "message": str(error)})

    def play_url(self, url):
        if not isinstance(url, str) or not url.strip():
            return False, "請提供 YouTube 影片連結"
        url = url.strip()
        host = urlparse(url).hostname or ""
        if host not in {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}:
            return False, "請提供 YouTube 影片連結"
        try:
            self.stop()
            self.process = subprocess.Popen(
                ["mpv", "--no-video", "--force-window=no", url],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except (FileNotFoundError, OSError) as error:
            self.process = None
            return False, str(error)
        self.publish({"state": "playing", "url": url})
        return True, None

    def handle_stop(self, payload, retained=False):
        if not retained:
            self.stop()
            self.publish({"state": "stopped"})

    def stop(self):
        if self.process and self.process.poll() is None:
            self.process.terminate()
        self.process = None

    def publish(self, data):
        self.client.publish(TOPIC_STATE, json.dumps(data), qos=1, retain=True)
