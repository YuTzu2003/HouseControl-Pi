from __future__ import annotations
import logging
import subprocess
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from .config import (
    CAMERA_RETENTION_MINUTES,
    CAMERA_SEGMENT_SECONDS,
    CAMERA_VIDEO_CODEC,
    CAMERA_VIDEO_INPUT_ARGS,
    LIVE_FRAME_PATH,
    RECORDINGS_DIR,
)

LOGGER = logging.getLogger(__name__)

def remove_expired_recordings(now: datetime | None = None) -> None:
    now = now or datetime.now(timezone.utc)
    cutoff = now.timestamp() - timedelta(minutes=CAMERA_RETENTION_MINUTES).total_seconds()
    for recording in RECORDINGS_DIR.glob("*.mp4"):
        started_at = _recording_started_at(recording)
        if started_at < cutoff:
            LOGGER.info("刪除過期片段：%s", recording.name)
            recording.unlink()


def _recording_started_at(recording: Path) -> float:
    try:
        timestamp = recording.name.split(".", maxsplit=1)[0]
        return datetime.strptime(timestamp, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc).timestamp()
    except ValueError:
        return recording.stat().st_mtime

def record_segment() -> bool:
    started_at = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    recording = RECORDINGS_DIR / f"{started_at}.mp4"
    partial_recording = RECORDINGS_DIR / f"{started_at}.partial.mp4"
    command = [
        "ffmpeg",
        "-nostdin",
        "-hide_banner",
        "-loglevel",
        "warning",
        "-t",
        str(CAMERA_SEGMENT_SECONDS),
        *CAMERA_VIDEO_INPUT_ARGS,
        "-an",
        "-c:v",
        CAMERA_VIDEO_CODEC,
        "-pix_fmt",
        "yuv420p",
        "-movflags",
        "+faststart",
        str(partial_recording),
        "-map",
        "0:v:0",
        "-an",
        "-c:v",
        "mjpeg",
        "-q:v",
        "5",
        "-vf",
        "fps=5",
        "-update",
        "1",
        str(LIVE_FRAME_PATH),
    ]
    LOGGER.info("開始錄製片段：%s", recording.name)
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        LOGGER.error("ffmpeg 錄影失敗，結束碼：%s", result.returncode)
        return False

    partial_recording.replace(recording)
    LOGGER.info("完成錄製片段：%s", recording.name)
    return True

def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    RECORDINGS_DIR.mkdir(parents=True, exist_ok=True)
    LOGGER.info("攝影機服務已啟動：每 %s 秒一段，保留 %s 分鐘", CAMERA_SEGMENT_SECONDS, CAMERA_RETENTION_MINUTES,)
    while True:
        remove_expired_recordings()
        if not record_segment():
            time.sleep(5)

if __name__ == "__main__":
    main()
