#!/usr/bin/env bash
# 一鍵啟動 House Control：攝影機錄影、RFID／燈光／音樂 MQTT 控制器與 FastAPI。
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
UVICORN_BIN="$PROJECT_DIR/.venv/bin/uvicorn"
PID_DIR="$PROJECT_DIR/run"

if [[ ! -x "$PYTHON_BIN" || ! -x "$UVICORN_BIN" ]]; then
  if command -v uv >/dev/null 2>&1; then
    echo "找不到 Python 虛擬環境，正在執行 uv sync..."
    (cd "$PROJECT_DIR" && uv sync)
  else
    echo "找不到 Python 虛擬環境或 uv，請先執行：cd '$PROJECT_DIR' && uv sync" >&2
    exit 1
  fi
fi

cd "$PROJECT_DIR"
mkdir -p logs
mkdir -p recordings
mkdir -p "$PID_DIR"

read_pid() {
  local name="$1"
  local file="$PID_DIR/$name.pid"
  [[ -f "$file" ]] && cat "$file" || true
}

stop_services() {
  local name pid
  for name in camera controller api; do
    pid="$(read_pid "$name")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      echo "停止 $name（PID $pid）..."
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_DIR/$name.pid"
  done
}

status_services() {
  local name pid state
  for name in camera controller api; do
    pid="$(read_pid "$name")"
    state="停止"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then state="執行中"; fi
    echo "$name: $state${pid:+（PID $pid）}"
  done
}

case "${1:-start}" in
  stop)
    stop_services
    exit 0
    ;;
  status)
    status_services
    exit 0
    ;;
  start)
    ;;
  *)
    echo "用法：$0 [start|stop|status]" >&2
    exit 2
    ;;
esac

has_live_service() {
  local name pid
  for name in camera controller api; do
    pid="$(read_pid "$name")"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then return 0; fi
  done
  return 1
}

if has_live_service; then
  echo "House Control 可能已在執行，請先執行：$0 stop" >&2
  status_services
  exit 1
fi

cleanup() {
  echo "正在停止 House Control..."
  kill "${CAMERA_PID:-}" "${CONTROLLER_PID:-}" "${API_PID:-}" 2>/dev/null || true
  wait "${CAMERA_PID:-}" "${CONTROLLER_PID:-}" "${API_PID:-}" 2>/dev/null || true
  rm -f "$PID_DIR/camera.pid" "$PID_DIR/controller.pid" "$PID_DIR/api.pid"
}
trap cleanup EXIT INT TERM

write_pid() {
  echo "$2" > "$PID_DIR/$1.pid"
}

echo "啟動攝影機錄影（每 ${CAMERA_SEGMENT_SECONDS:-300} 秒完成一段；影片：$PROJECT_DIR/recordings）..."
"$PYTHON_BIN" -m iot_control.camera > logs/camera.log 2>&1 &
CAMERA_PID=$!
write_pid camera "$CAMERA_PID"

echo "啟動 MQTT 控制器..."
start_controller() {
  "$PYTHON_BIN" -m iot_control.house_pi > logs/controller.log 2>&1 &
  CONTROLLER_PID=$!
  write_pid controller "$CONTROLLER_PID"
}
start_controller

echo "啟動 API：http://0.0.0.0:8000"
"$UVICORN_BIN" app.server:app --host 0.0.0.0 --port 8000 > logs/api.log 2>&1 &
API_PID=$!
write_pid api "$API_PID"

sleep 1
if ! kill -0 "$CAMERA_PID" 2>/dev/null || ! kill -0 "$API_PID" 2>/dev/null; then
  echo "攝影機或 API 啟動失敗，請查看 logs/camera.log 與 logs/api.log" >&2
  exit 1
fi

echo "House Control 已啟動。App API：http://<樹莓派IP>:8000"
echo "錄影檔位置：$PROJECT_DIR/recordings"
echo "按 Ctrl+C 可同時停止所有服務。"

# 攝影機與 API 是手機監看所必需的服務；控制器（MQTT／RFID／DHT）
# 即使暫時失敗，也不能使這兩項服務一併停止。
while true; do
  if ! kill -0 "$CAMERA_PID" 2>/dev/null || ! kill -0 "$API_PID" 2>/dev/null; then
    echo "攝影機或 API 已停止，請查看 logs/camera.log 與 logs/api.log" >&2
    exit 1
  fi
  if ! kill -0 "$CONTROLLER_PID" 2>/dev/null; then
    echo "MQTT 控制器已停止，正在重新啟動；請查看 logs/controller.log" >&2
    start_controller
  fi
  sleep 2
done
