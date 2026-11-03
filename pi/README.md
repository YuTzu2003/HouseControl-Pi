# Raspberry Pi 端

`start_house_control.sh` 是單一啟動入口，會一起啟動攝影機、MQTT 控制器和 FastAPI。第一次執行若尚未建立 `.venv`，腳本會自動執行 `uv sync`（仍需先安裝 `uv`、MQTT broker、`ffmpeg`、`mpv` 與相機／RFID 所需的系統套件）。

```bash
cd ~/Desktop/IOT_Control/pi
./start_house_control.sh
```

另外開一個終端機可以查狀態或停止：

```bash
./start_house_control.sh status
./start_house_control.sh stop
```

所有服務的紀錄在 `logs/`：

- `controller.log`：燈光、排程、RFID、音樂與情境執行
- `api.log`：手機 API
- `camera.log`：攝影機錄影

排程資料與情境資料都存於 `house-pi.db`，重啟後會保留。排程由樹莓派本地時間判定，請先確認：

```bash
timedatectl
date
```

## 自動化資料

`/automations` 支援舊欄位 `time`／`action`，也支援新的 `start_time`、`end_time`、`start_action`、`end_action`、`start_mode`、`end_mode`、`start_brightness`、`end_brightness` 與 `scene_id`。星期使用 Python 的星期編號：週一 `0` 到週日 `6`。

`/scenes` 的動作格式例如：

```json
{
  "name": "電影模式",
  "actions": [
    {"device": "light", "on": true, "mode": "warm_yellow", "brightness": 20},
    {"device": "music", "command": "stop"}
  ],
  "enabled": true
}
```

情境會透過 `house/scene/execute` 執行，結果發佈到 `house/scene/result`。陌生 RFID 卡片會發佈 `house/rfid/event` 的 `access_denied`，並在卡片離開感應區後才重新武裝下一次警報。
