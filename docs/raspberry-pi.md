# Raspberry Pi 架設指南

## 1. 建議環境

- Raspberry Pi OS 64-bit。
- Python 3.11 以上。
- 與手機相同的區域網路。
- USB Webcam；程式預設使用 `/dev/video0`。
- USB 音響或 Raspberry Pi 可用的音訊輸出。
- 依需求接上 RGB LED、DHT11、MFRC522 與蜂鳴器。

## 2. 安裝系統套件

```bash
sudo apt update
sudo apt install -y mosquitto mosquitto-clients ffmpeg mpv alsa-utils curl
sudo systemctl enable --now mosquitto
```

MFRC522 需要 SPI。執行 `sudo raspi-config`，在 Interface Options 中啟用 SPI，完成後重新啟動 Raspberry Pi。

## 3. 安裝 Python 環境

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
cd ~/housecontrol_pi/pi
uv sync
```

`uv sync` 會建立 `.venv` 並安裝 FastAPI、MQTT、RFID、GPIO 與 yt-dlp 等 Python 套件。

## 4. 設定 Mosquitto

目前 App 預設可使用匿名 MQTT。只建議在可信任的家庭區域網路使用。

建立設定檔：

```bash
sudo nano /etc/mosquitto/conf.d/housecontrol.conf
```

填入：

```conf
listener 1883 0.0.0.0
allow_anonymous true
```

重新啟動並確認狀態：

```bash
sudo systemctl restart mosquitto
sudo systemctl status mosquitto
```

## 5. 硬體與環境設定

```bash
cd ~/housecontrol_pi/pi
cp house_control.env.example house_control.env
nano house_control.env
```

預設 RGB LED 使用 BOARD 腳位 `29`、`31`、`33`，依序對應紅、綠、藍：

```bash
HOUSE_CONTROL_LED_CHANNEL_ORDER=rgb
HOUSE_CONTROL_LED_COMMON_ANODE=false
```

如果通道接線順序不同，可改成 `brg` 等 RGB 排列。若燈具為共陽極，將 `HOUSE_CONTROL_LED_COMMON_ANODE` 改為 `true`。

DHT11 預設使用 BOARD 腳位 `7`。攝影機預設為 `/dev/video0` 的 USB Webcam。

需要指定 USB 音響時，先查詢裝置：

```bash
mpv --audio-device=help
```

再於 `house_control.env` 加入：

```bash
HOUSE_CONTROL_AUDIO_DEVICE=<mpv 顯示的音訊裝置名稱>
```

## 6. 啟動服務

```bash
cd ~/housecontrol_pi/pi
chmod +x start.sh
./start.sh
```

常用管理指令：

```bash
./start.sh status
./start.sh logs
./start.sh stop
./start.sh led-test
```

執行中的資料會放在：

- `logs/`：服務紀錄。
- `recordings/`：即時圖片與錄影片段。
- `run/`：PID 檔案。
- `house-pi.db`：SQLite 資料庫。

## 7. 驗證服務

```bash
hostname -I
curl http://127.0.0.1:8000/health
./start.sh status
```

測試 MQTT：

```bash
mosquitto_pub -h 127.0.0.1 -t house/room/light/set -m '{"on":true,"mode":"warm_white","brightness":60}'
```

測試音響：

```bash
speaker-test -t wav -c 2
which mpv
.venv/bin/yt-dlp --version
```

## 8. 設定開機自動啟動

先確認專案的實際路徑與 Linux 使用者名稱，再建立 systemd 服務：

```bash
sudo nano /etc/systemd/system/house-control.service
```

範例：

```ini
[Unit]
Description=HouseControl Pi
After=network-online.target mosquitto.service
Wants=network-online.target

[Service]
Type=simple
User=<Linux 使用者名稱>
WorkingDirectory=/home/<Linux 使用者名稱>/housecontrol_pi/pi
ExecStart=/home/<Linux 使用者名稱>/housecontrol_pi/pi/start.sh start
ExecStop=/home/<Linux 使用者名稱>/housecontrol_pi/pi/start.sh stop
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

套用設定：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now house-control
sudo systemctl status house-control
journalctl -u house-control -f
```

## 9. 手機連線

在 Raspberry Pi 執行 `hostname -I` 取得 IP，例如 `192.168.1.50`。App 第一次開啟時輸入：

- 家庭連線位址：`192.168.1.50`
- 連線通道：`1883`
- 家庭帳號、密碼：匿名 MQTT 時保持空白

手機需能存取 Raspberry Pi 的 `1883` 與 `8000` 連接埠。

## 10. 故障排查

### 服務沒有啟動

```bash
./start.sh status
tail -n 100 logs/controller.log
tail -n 100 logs/api.log
tail -n 100 logs/camera.log
```

### RGB 顏色不正確

```bash
./start.sh stop
./start.sh led-test
```

依測試結果修改 `HOUSE_CONTROL_LED_CHANNEL_ORDER` 或 `HOUSE_CONTROL_LED_COMMON_ANODE`。

### 音樂沒有聲音

```bash
speaker-test -t wav -c 2
mpv --audio-device=help
tail -n 100 logs/controller.log
```

### 攝影機沒有畫面

```bash
ls -l /dev/video0
ffmpeg -f v4l2 -list_formats all -i /dev/video0
tail -n 100 logs/camera.log
```

### 手機無法連線

- 確認手機與 Raspberry Pi 在同一個網路。
- 確認 `1883` 與 `8000` 未被防火牆阻擋。
- 使用手機瀏覽器開啟 `http://<Raspberry Pi IP>:8000/health`。
- 使用 `./start.sh logs` 查看控制器是否收到指令。
