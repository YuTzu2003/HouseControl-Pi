# Raspberry Pi 端

## 目錄職責

```text
pi/
├── start_house_control.sh       # 唯一啟動、停止、日誌與 RGB 測試入口
├── house_control.env.example    # 本機硬體設定範例（不提交）
├── house_control/
│   ├── api.py                   # FastAPI：供 App 讀寫排程、情境、紀錄與影片
│   ├── controller.py            # MQTT 控制器、資料庫、排程與情境執行
│   ├── light.py                 # RGB LED MQTT 控制
│   ├── music.py                 # YouTube/mpv 音樂控制
│   ├── rfid.py                  # RFID 卡片事件與綁定
│   ├── sensor.py                # DHT11 感測器讀取
    ├── camera.py                # 攝影機分段錄影與清理
    └── config.py                # 錄影與攝影機共用設定
└── tests/
    ├── test_rfid.py             # RFID 手動讀卡測試
    └── test_rgb_wiring.py       # RGB 接線測試
```

`logs/`、`recordings/`、`run/`、`house-pi.db*`、`.venv/` 都是樹莓派執行後自動產生的資料，不應複製進 Git。`house_control.env` 是每台樹莓派自己的硬體設定，也不提交。

`start_house_control.sh` 是單一啟動入口，會一起啟動攝影機、MQTT 控制器和 FastAPI。第一次執行若尚未建立 `.venv`，腳本會自動執行 `uv sync`（仍需先安裝 MQTT broker、`ffmpeg`、`mpv` 與相機／RFID 所需的系統套件；`yt-dlp` 會由 `uv sync` 安裝）。

```bash
cd ~/Desktop/IOT_Control/pi
./start_house_control.sh
```

另外開一個終端機可以查狀態或停止：

```bash
./start_house_control.sh status
./start_house_control.sh stop
```

要即時查看樹莓派是否收到燈光、音樂或情境指令，可開另一個終端機執行：

```bash
./start_house_control.sh logs
```

## MQTT 匿名連線

目前樹莓派控制器與 App 預設使用匿名 MQTT，不需要 `MQTT_USER` 或密碼。Mosquitto 也必須允許匿名連線；在樹莓派設定檔加入或確認：

```conf
listener 1883 0.0.0.0
allow_anonymous true
```

套用設定：

```bash
sudo systemctl restart mosquitto
sudo systemctl status mosquitto
```

App 的 MQTT 設定頁中，使用者名稱與密碼都留白即可。匿名 MQTT 只建議在可信任的區域網路使用，因為同網段裝置可以發送控制指令。

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

## RGB 燈光校正

預設假設實體腳位 `29`、`31`、`33` 依序接到 RGB 燈的紅、綠、藍通道，且燈具是共陰極。若所有模式都偏紅、顏色對不上，先確認接線與燈具類型。

先執行可重現的接線測試。測試和 MQTT 控制器會共用 GPIO，請先停止服務：

```bash
./start_house_control.sh stop
./start_house_control.sh led-test
```

測試會依序顯示紅、綠、藍、白、關閉，各三秒。若三種顏色都有顯示但順序錯誤，將校正永久存入本機設定，不必每次輸入 `export`：

```bash
cp house_control.env.example house_control.env
nano house_control.env
./start_house_control.sh
```

例如腳位 `29`、`31`、`33` 實際分別接到藍、紅、綠通道時，將 `house_control.env` 改為：

```bash
HOUSE_CONTROL_LED_CHANNEL_ORDER=brg
```

若 RGB 燈或驅動器是共陽極，也在 `house_control.env` 加入：

```bash
HOUSE_CONTROL_LED_COMMON_ANODE=true
```

eMeet M0 USB 喇叭的音訊輸出也放在同一個 `house_control.env`，讓背景服務可使用正確喇叭：

```bash
HOUSE_CONTROL_AUDIO_DEVICE=pipewire/alsa_output.usb-EMEET_eMeet_M0_000000000000000000000654d6565742020200731b6ab7643a2e3eMeet_M0-00.analog-stereo
```

可用以下指令確認樹莓派有收到不同模式（需安裝 `mosquitto-clients`）：

```bash
mosquitto_pub -h 127.0.0.1 -t house/room/light/set -m '{"on":true,"mode":"warm_yellow","brightness":100}'
mosquitto_pub -h 127.0.0.1 -t house/room/light/set -m '{"on":true,"mode":"cool_white","brightness":100}'
```

若 MQTT 狀態已改變但實體燈仍完全只有紅色，代表綠／藍通道接線、限流電阻、共用腳或 RGB 驅動電路需要檢查。

## 喇叭播放故障排查

音樂播放需要樹莓派安裝 `mpv`，並讓專案環境包含 `yt-dlp`：

```bash
sudo apt update
sudo apt install -y mpv alsa-utils
uv sync
```

先確認樹莓派本身能出聲，再從 App 播放：

```bash
speaker-test -t wav -c 2
which mpv
.venv/bin/yt-dlp --version
```

App 會顯示樹莓派回傳的播放錯誤；詳細的 `mpv` 錯誤會寫在 `logs/controller.log`。若預設音效裝置不是正確的喇叭，先單獨列出裝置，再依輸出的名稱設定環境變數：

```bash
mpv --audio-device=help
nano house_control.env
# 在 house_control.env 填入：HOUSE_CONTROL_AUDIO_DEVICE=<你的裝置名稱>
./start_house_control.sh
```
