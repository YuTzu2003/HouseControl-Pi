from __future__ import annotations
import json
import logging
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from typing import Optional
from urllib.parse import parse_qs, urlparse

TOPIC_PLAY = "house/youtube/play"
TOPIC_STOP = "house/youtube/stop"
TOPIC_PAUSE = "house/youtube/pause"
TOPIC_VOLUME = "house/youtube/volume"
TOPIC_STATUS = "house/youtube/status"

LOGGER = logging.getLogger(__name__)
ALLOWED_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}
_cached_audio_device: Optional[str] = None

def _audio_device() -> str:
    global _cached_audio_device
    if _cached_audio_device is not None:
        return _cached_audio_device
    dev = os.environ.get("HOUSE_CONTROL_AUDIO_DEVICE", "").strip()
    if dev and dev != "auto":
        _cached_audio_device = dev
        return dev
    detected = _detect_usb_audio()
    _cached_audio_device = detected or "auto"
    return _cached_audio_device


def _detect_usb_audio() -> Optional[str]:
    """Scan mpv --audio-device=help for a USB/pipewire device as fallback."""
    mpv = shutil.which("mpv")
    if not mpv:
        return None
    try:
        result = subprocess.run(
            [mpv, "--audio-device=help"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5,
        )
        for line in result.stdout.decode("utf-8", "replace").splitlines():
            line = line.strip()
            if line.startswith("'") and "usb" in line.lower():
                device_id = line.split("'")[1]
                if device_id:
                    print(f"[YouTube] 自動偵測到 USB 音訊裝置：{device_id}")
                    return device_id
    except Exception as exc:
        print(f"[YouTube] 自動偵測音訊裝置失敗：{exc}")
    return None
DEFAULT_VOLUME = max(0, min(100, int(os.environ.get("HOUSE_CONTROL_YOUTUBE_VOLUME", "80"))))
VIDEO_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{11}$")


def _find_ytdlp() -> Optional[str]:
    """沿用 music.py 的策略：先找 uv 建立的 .venv，再退回 PATH。"""
    for name in ("yt-dlp", "youtube-dl"):
        venv_path = Path(sys.executable).with_name(name)
        if venv_path.is_file() and os.access(venv_path, os.X_OK):
            return str(venv_path)
    for name in ("yt-dlp", "youtube-dl"):
        path = shutil.which(name)
        if path:
            return path
    return None


def _normalise_url(raw: str) -> Optional[str]:
    """接受完整連結或純粹的 11 碼影片 ID，一律轉成 watch?v= 格式。"""
    if not isinstance(raw, str):
        return None
    candidate = raw.strip()
    if not candidate:
        return None
    if VIDEO_ID_PATTERN.fullmatch(candidate):
        return f"https://www.youtube.com/watch?v={candidate}"
    parsed = urlparse(candidate)
    host = (parsed.hostname or "").lower().rstrip(".")
    if parsed.scheme not in {"http", "https"} or host not in ALLOWED_HOSTS:
        return None
    if host == "youtu.be":
        video_id = parsed.path.lstrip("/")
        if VIDEO_ID_PATTERN.fullmatch(video_id):
            return f"https://www.youtube.com/watch?v={video_id}"
        return None
    if parsed.path == "/watch":
        video_id = parse_qs(parsed.query).get("v", [""])[0]
        if VIDEO_ID_PATTERN.fullmatch(video_id):
            return f"https://www.youtube.com/watch?v={video_id}"
    return None


def _fetch_title(ytdlp_path: str, url: str, timeout: float = 10.0) -> Optional[str]:
    """用 yt-dlp 抓取影片標題，失敗就回傳 None，不阻擋播放。"""
    try:
        result = subprocess.run(
            [ytdlp_path, "--no-warnings", "--skip-download", "--print", "title", url],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            check=False,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired) as error:
        LOGGER.warning("取得 YouTube 標題失敗：%s", error)
        return None
    if result.returncode != 0:
        LOGGER.warning("取得 YouTube 標題失敗：rc=%s stderr=%s", result.returncode,
                       result.stderr.decode("utf-8", "replace").strip())
        return None
    title = result.stdout.decode("utf-8", "replace").strip()
    return title or None


class YouTubeService:
    """管理 mpv 子程序、IPC socket 與 MQTT 狀態回報。"""

    def __init__(self, client):
        self.client = client
        self.process: Optional[subprocess.Popen] = None
        self.ipc_path: Optional[str] = None
        self.current_url: Optional[str] = None
        self.current_title: Optional[str] = None
        self.volume: int = DEFAULT_VOLUME
        self._lock = threading.Lock()

    # ---------- MQTT 入口 ----------

    def handle_play(self, payload: bytes, retained: bool = False) -> None:
        if retained or len(payload) > 4096:
            return
        try:
            raw = payload.decode("utf-8")
            data = json.loads(raw) if raw.strip().startswith("{") else {"url": raw}
            url_value = data.get("url") or data.get("video_id")
        except (TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError, AttributeError) as error:
            LOGGER.exception("YouTube 播放指令格式錯誤")
            self._publish_error(str(error))
            return
        threading.Thread(target=self._play_async, args=(url_value,), daemon=True).start()

    def _play_async(self, raw_url) -> None:
        try:
            print(f"[YouTube] _play_async 開始：{raw_url}")
            ok, error = self.play(raw_url)
            if ok:
                print(f"[YouTube] 播放已啟動：{self.current_url}")
            else:
                print(f"[YouTube] 播放失敗：{error}")
        except Exception as exc:
            print(f"[YouTube] 播放例外：{exc}")
            LOGGER.exception("YouTube 播放執行期間發生錯誤")
            self._publish_error("播放時發生內部錯誤")

    def handle_stop(self, payload: bytes, retained: bool = False) -> None:
        if retained:
            return
        self.stop()
        self.publish_status(state="stopped")
        LOGGER.info("YouTube 停止指令已套用")

    def handle_volume(self, payload: bytes, retained: bool = False) -> None:
        if retained or len(payload) > 256:
            return
        try:
            raw = payload.decode("utf-8").strip()
            data = json.loads(raw) if raw.startswith("{") else {"volume": raw}
            value = data.get("volume")
            volume = int(float(value))
        except (TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
            self._publish_error(f"音量格式錯誤：{error}")
            return
        if not 0 <= volume <= 100:
            self._publish_error("音量必須介於 0～100")
            return
        self.set_volume(volume)

    def handle_pause(self, payload: bytes, retained: bool = False) -> None:
        if retained:
            return
        self.toggle_pause()

    # ---------- 核心邏輯 ----------

    def play(self, raw_url):
        url = _normalise_url(raw_url)
        print(f"[YouTube] normalise: {raw_url!r} → {url!r}")
        if url is None:
            return self._fail("請提供 youtube.com 或 youtu.be 的連結，或 11 碼影片 ID")
        mpv_path = shutil.which("mpv")
        ytdlp_path = _find_ytdlp()
        print(f"[YouTube] mpv={mpv_path}, ytdlp={ytdlp_path}")
        if not mpv_path:
            return self._fail("樹莓派找不到 mpv，請先安裝：sudo apt install mpv")
        if not ytdlp_path:
            return self._fail("樹莓派找不到 yt-dlp，請先執行 uv sync 或安裝 yt-dlp")

        print("[YouTube] 正在取得標題...")
        title = _fetch_title(ytdlp_path, url)
        print(f"[YouTube] 標題={title!r}")
        self.stop()
        ipc_path = _make_ipc_path()
        print(f"[YouTube] ipc_path={ipc_path}")
        command = [
            mpv_path,
            "--no-video",
            "--force-window=no",
            "--no-terminal",
            "--msg-level=all=warn",
            "--ytdl-format=bestaudio/best",
            f"--volume={self.volume}",
            f"--input-ipc-server={ipc_path}",
        ]
        audio_dev = _audio_device()
        print(f"[YouTube] audio_device={audio_dev!r}")
        if audio_dev and audio_dev != "auto":
            command.append(f"--audio-device={audio_dev}")
        command.append(url)
        environment = os.environ.copy()
        environment["PATH"] = f"{Path(ytdlp_path).parent}{os.pathsep}{environment.get('PATH', '')}"
        for pw_var in ("XDG_RUNTIME_DIR", "DBUS_SESSION_BUS_ADDRESS", "PULSE_SERVER"):
            print(f"[YouTube] {pw_var}={environment.get(pw_var, '(未設定)')}")
        if "XDG_RUNTIME_DIR" not in environment:
            environment["XDG_RUNTIME_DIR"] = f"/run/user/{os.getuid()}"
            print(f"[YouTube] 補上 XDG_RUNTIME_DIR={environment['XDG_RUNTIME_DIR']}")
        print(f"[YouTube] 啟動 mpv：{' '.join(command)}")
        try:
            process = subprocess.Popen(
                command,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=environment,
            )
        except (FileNotFoundError, OSError) as error:
            print(f"[YouTube] mpv 啟動失敗：{error}")
            return self._fail(str(error))
        print(f"[YouTube] mpv PID={process.pid}")
        threading.Thread(target=self._drain_mpv_stderr, args=(process,), daemon=True).start()

        with self._lock:
            self.process = process
            self.ipc_path = ipc_path
            self.current_url = url
            self.current_title = title
        threading.Thread(target=self._watch, args=(process, url, ipc_path), daemon=True).start()
        self.publish_status(state="playing")
        return True, None

    def stop(self) -> None:
        with self._lock:
            process = self.process
            ipc_path = self.ipc_path
            self.process = None
            self.ipc_path = None
            self.current_url = None
            self.current_title = None
        if process and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        _cleanup_ipc(ipc_path)

    def set_volume(self, volume: int) -> None:
        self.volume = volume
        with self._lock:
            ipc_path = self.ipc_path
            playing = self.process is not None and self.process.poll() is None
        if playing and ipc_path:
            try:
                _mpv_command(ipc_path, ["set_property", "volume", volume])
            except OSError as error:
                LOGGER.warning("設定 mpv 音量失敗：%s", error)
                self.publish_status(message="音量指令送達 mpv 失敗，實際音量可能不同步")
                return
        self.publish_status()

    def toggle_pause(self) -> None:
        with self._lock:
            ipc_path = self.ipc_path
            alive = self.process is not None and self.process.poll() is None
        if not alive or not ipc_path:
            return
        try:
            _mpv_command(ipc_path, ["cycle", "pause"])
        except OSError as error:
            LOGGER.warning("暫停/繼續失敗：%s", error)
            return
        time.sleep(0.15)
        try:
            paused = _mpv_get_property(ipc_path, "pause")
            state = "paused" if paused else "playing"
        except OSError:
            state = "playing"
        self.publish_status(state=state)

    # ---------- 狀態回報 ----------

    def publish_status(self, state: Optional[str] = None, message: Optional[str] = None) -> None:
        with self._lock:
            playing = self.process is not None and self.process.poll() is None
            url = self.current_url
            title = self.current_title
        if state is None:
            state = "playing" if playing else "stopped"
        payload = {
            "state": state,
            "url": url,
            "title": title,
            "volume": self.volume,
        }
        if message:
            payload["message"] = message
        self.client.publish(TOPIC_STATUS, json.dumps(payload, ensure_ascii=False),
                            qos=1, retain=True)

    def _publish_error(self, message: str) -> None:
        LOGGER.error("%s", message)
        self.publish_status(state="error", message=message)

    def _fail(self, message: str):
        self._publish_error(message)
        return False, message

    @staticmethod
    def _drain_mpv_stderr(process: subprocess.Popen) -> None:
        try:
            for line in process.stderr:
                text = line.decode("utf-8", "replace").rstrip()
                if text:
                    print(f"[mpv stderr] {text}")
        except Exception:
            pass

    def _watch(self, process: subprocess.Popen, url: str, ipc_path: str) -> None:
        return_code = process.wait()
        with self._lock:
            if self.process is not process:
                return
            self.process = None
            self.ipc_path = None
            self.current_url = None
            self.current_title = None
        _cleanup_ipc(ipc_path)
        if return_code == 0:
            self.publish_status(state="stopped")
            return
        message = f"mpv 結束（代碼 {return_code}）。請檢查網路、yt-dlp 與喇叭輸出。"
        LOGGER.error("%s URL=%s", message, url)
        self.publish_status(state="error", message=message)


# ---------- 輔助函式 ----------


def _cleanup_ipc(ipc_path: Optional[str]) -> None:
    if not ipc_path:
        return
    try:
        os.unlink(ipc_path)
    except OSError:
        pass
    try:
        os.rmdir(os.path.dirname(ipc_path))
    except OSError:
        pass


def _make_ipc_path() -> str:
    """為每次播放產生唯一的 IPC socket 路徑，放在只有 owner 可進入的目錄。"""
    sock_dir = tempfile.mkdtemp(prefix="house-youtube-")
    os.chmod(sock_dir, 0o700)
    return os.path.join(sock_dir, "mpv.sock")


def _mpv_command(ipc_path: str, command: list, timeout: float = 1.5) -> None:
    """用 Unix socket 送單筆 JSON RPC 給 mpv，丟了就算，不等待回應。"""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.settimeout(timeout)
        sock.connect(ipc_path)
        payload = json.dumps({"command": command}).encode("utf-8") + b"\n"
        sock.sendall(payload)
    finally:
        sock.close()


def _mpv_get_property(ipc_path: str, name: str, timeout: float = 1.5):
    """讀取 mpv 屬性值，回傳 data 欄位。"""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.settimeout(timeout)
        sock.connect(ipc_path)
        payload = json.dumps({"command": ["get_property", name]}).encode("utf-8") + b"\n"
        sock.sendall(payload)
        buf = b""
        while b"\n" not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                break
            buf += chunk
        result = json.loads(buf.split(b"\n", 1)[0])
        return result.get("data")
    finally:
        sock.close()
