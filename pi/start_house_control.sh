#!/usr/bin/env bash
# 一鍵啟動 House Control：RFID／燈光 MQTT 控制器與 FastAPI。
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
UVICORN_BIN="$PROJECT_DIR/.venv/bin/uvicorn"

if [[ ! -x "$PYTHON_BIN" || ! -x "$UVICORN_BIN" ]]; then
  echo "找不到 Python 虛擬環境，請先執行：cd '$PROJECT_DIR' && uv sync" >&2
  exit 1
fi

cd "$PROJECT_DIR"
mkdir -p logs

cleanup() {
  echo "正在停止 House Control..."
  kill "${CONTROLLER_PID:-}" "${API_PID:-}" 2>/dev/null || true
  wait "${CONTROLLER_PID:-}" "${API_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "啟動 MQTT 控制器..."
"$PYTHON_BIN" house_pi.py > logs/controller.log 2>&1 &
CONTROLLER_PID=$!

echo "啟動 API：http://0.0.0.0:8000"
"$UVICORN_BIN" app.server:app --host 0.0.0.0 --port 8000 > logs/api.log 2>&1 &
API_PID=$!

sleep 1
if ! kill -0 "$CONTROLLER_PID" 2>/dev/null || ! kill -0 "$API_PID" 2>/dev/null; then
  echo "啟動失敗，請查看 logs/controller.log 與 logs/api.log" >&2
  exit 1
fi

echo "House Control 已啟動。App API：http://<樹莓派IP>:8000"
echo "按 Ctrl+C 可同時停止所有服務。"
wait -n "$CONTROLLER_PID" "$API_PID"
echo "其中一個服務已停止，請查看 logs/ 內的日誌。" >&2
exit 1
