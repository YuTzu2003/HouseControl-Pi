from pathlib import Path

RECORDINGS_DIR = Path("/var/lib/house-control/recordings")
LIVE_FRAME_PATH = RECORDINGS_DIR / "live.jpg"
CAMERA_SEGMENT_SECONDS = 300
CAMERA_RETENTION_MINUTES = 20
USB_WEBCAM_VIDEO_INPUT_ARGS = [
    "-f", "v4l2",
    "-framerate", "30",
    "-video_size", "1280x720",
    "-input_format", "mjpeg",
    "-i", "/dev/video0",
]

USB_WEBCAM_AUDIO_INPUT_ARGS = [
    "-f", "alsa",
    "-i", "default",
]


CSI_CAMERA_COMMAND = [
    "rpicam-vid",
    "--timeout", "0",
    "--nopreview",
    "--codec", "h264",
    "--inline",
    "--width", "1280",
    "--height", "720",
    "--framerate", "30",
    "--output", "-",
]

# 預設：USB Webcam。
CAMERA_VIDEO_INPUT_ARGS = USB_WEBCAM_VIDEO_INPUT_ARGS
CAMERA_AUDIO_INPUT_ARGS = USB_WEBCAM_AUDIO_INPUT_ARGS

# 若改用 CSI Pi Camera，未來錄影程式應改用以下設定：
# CAMERA_VIDEO_COMMAND = CSI_CAMERA_COMMAND
# CAMERA_AUDIO_INPUT_ARGS = USB_WEBCAM_AUDIO_INPUT_ARGS

CAMERA_VIDEO_CODEC = "h264_v4l2m2m"
CAMERA_AUDIO_CODEC = "aac"
