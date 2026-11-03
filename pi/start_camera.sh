#!/usr/bin/env bash
# 相容舊指令：攝影機、手機 API 與家庭控制現在由同一個服務啟動，
# 避免只錄影而讓手機無法連線到 port 8000。
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec "$PROJECT_DIR/start_house_control.sh"
