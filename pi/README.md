# 樹莓派部署與 App 連線操作手冊

本文件說明如何在樹莓派啟動家庭控制系統，以及讓電腦或手機 App 透過 MQTT 與 HTTP API 操作它。

> 請將文件內的 `PI_IP` 替換成樹莓派在家中網路的 IP，例如 `192.168.1.50`。

## 系統連線架構

```text
電腦／手機 App
  ├─ MQTT（PI_IP:1883）──> 燈光、音樂、RFID 綁卡控制
  └─ HTTP（PI_IP:8000）──> RFID、溫濕度、錄影片段查詢

樹莓派
  ├─ iot-control 主程式：RFID、燈光、音樂控制
  ├─ FastAPI：提供 App 查詢資料
  └─ house-camera systemd：持續錄影、分段 MP4、清理過期檔案
```

## 一、樹莓派首次安裝

### 1. 查詢樹莓派 IP

```bash
hostname -I
```

### 2. 下載與安裝專案

```bash
git clone https://github.com/YuTzu2003/HouseControl-Pi.git ~/Desktop/IOT_Control
cd ~/Desktop/IOT_Control
uv sync
```

更新既有專案：

```bash
cd ~/Desktop/IOT_Control
git pull
uv sync
```

### 3. 安裝攝影、音訊與串流播放工具

```bash
sudo apt update
sudo apt install -y ffmpeg v4l-utils alsa-utils mpv yt-dlp
```

查看 USB Webcam 與麥克風：

```bash
v4l2-ctl --list-devices
arecord -l
```

USB Webcam 通常會顯示影像裝置，如 `/dev/video0`。若有內建麥克風，也會出現在 `arecord -l` 的輸出中。

## 二、攝影機循環錄影

建立錄影與音樂資料夾：

```bash
sudo install -d -o pi -g pi /var/lib/house-control/recordings /var/lib/house-control/music
```

錄影服務預計使用以下設定：

```ini
# 60、120、180、240 或 300 秒；即每段 1～5 分鐘
CAMERA_SEGMENT_SECONDS=300

# 超過 20 分鐘的片段自動刪除
CAMERA_RETENTION_MINUTES=20

CAMERA_VIDEO_INPUT_ARGS="-f v4l2 -framerate 30 -video_size 1280x720 -input_format mjpeg -i /dev/video0"
CAMERA_AUDIO_INPUT_ARGS="-f alsa -i default"
```

在啟用連續錄影前，可先測試 Webcam：

```bash
ffmpeg -f v4l2 -framerate 30 -video_size 1280x720 -i /dev/video0 \
  -f alsa -i default -t 10 /tmp/webcam-test.mp4
ffprobe /tmp/webcam-test.mp4
```

若 Webcam 不支援上述格式，查詢支援的解析度與格式：

```bash
v4l2-ctl -d /dev/video0 --list-formats-ext
```

啟用錄影服務（假設專案位於 `/home/pi/Desktop/IOT_Control`）：

```bash
cd ~/Desktop/IOT_Control
chmod +x start_camera.sh
sudo install -m 644 house-camera.service /etc/systemd/system/house-camera.service
sudo systemctl daemon-reload
sudo systemctl enable --now house-camera
sudo systemctl status house-camera --no-pager
```

查看最新片段與服務日誌：

```bash
ls -lh /var/lib/house-control/recordings
journalctl -u house-camera -f
```

## 三、啟動目前已有的控制程式與 API

### 樹莓派喇叭播放 YouTube 音樂

先安裝播放器與 YouTube 擷取工具：

```bash
sudo apt update
sudo apt install -y mpv yt-dlp
```

確認喇叭是樹莓派的預設輸出：

```bash
speaker-test -t wav -c 2
```

手機的「音樂模式」可貼上 YouTube 分享連結；App 會發送 MQTT 指令到樹莓派，樹莓派以 `mpv` 從預設 ALSA 喇叭輸出聲音。

### 手機即時攝影機畫面

重新啟動攝影機服務與 API 後，App 首頁會持續更新最新畫面。它與錄影服務共用同一個 webcam，不會另外佔用 `/dev/video0`：

```bash
sudo systemctl restart house-camera
cd ~/Desktop/IOT_Control
bash start_house_control.sh
```

可用瀏覽器先確認最新影像：`http://PI_IP:8000/camera/live.jpg`

請開啟兩個樹莓派終端機。

第一個終端機啟動 MQTT 控制器（RFID、燈光）：

```bash
cd ~/Desktop/IOT_Control
uv run house_pi.py
```

第二個終端機啟動 App 查詢 API：

```bash
cd ~/Desktop/IOT_Control
uv run uvicorn app.server:app --host 0.0.0.0 --port 8000
```

確認 API 正常：

```bash
curl http://localhost:8000/health
```

## 四、App 端連線設定

| 用途 | 位址／Topic | 方法 |
| --- | --- | --- |
| MQTT Broker | `PI_IP:1883` | MQTT 連線 |
| API 根網址 | `http://PI_IP:8000` | HTTP |
| 燈光控制 | `house/room/light/set` | MQTT publish |
| RFID 刷卡事件 | `house/rfid/event` | MQTT subscribe |
| RFID 卡片 | `/rfid/cards` | HTTP GET |
| 溫濕度 | `/dht11/readings` | HTTP GET |

MQTT 設定目前在 `src/iot_control/house_pi.py`：

```python
MQTT_HOST = "127.0.0.1"
MQTT_PORT = 1883
MQTT_USER = "houseapp"
MQTT_PASSWORD = "123456"
```

> App 的 MQTT Host 必須設定為 `PI_IP`，不是 `127.0.0.1`；後者只代表 App 自己的裝置。

建議將 IP、帳密與 API URL 放入 App 的設定檔或 `.env`，不要寫死在程式碼中。

## 五、App 控制範例

### 燈光控制

發佈到 `house/room/light/set`：

```json
{
  "on": true,
  "mode": "warm_white",
  "brightness": 75
}
```

### 查詢資料

```text
GET http://PI_IP:8000/rfid/cards
GET http://PI_IP:8000/dht11/readings
```

## 六、從電腦端測試

在已安裝 `mosquitto-clients` 的電腦執行：

```bash
mosquitto_pub -h PI_IP -u houseapp -P 123456 \
  -t house/room/light/set \
  -m '{"on":true,"mode":"warm_white","brightness":75}'
```

查詢 API：

```bash
curl http://PI_IP:8000/rfid/cards
curl http://PI_IP:8000/dht11/readings
```

## 七、注意事項

- 樹莓派、電腦與手機需連到同一個內網，或透過 VPN 安全連線。
- 不要把 MQTT 的 1883 port 或 API 的 8000 port 直接轉發到公開網際網路。
- 加入攝影與音樂功能後，再依本文件第二節的 Webcam 測試與設定步驟執行。
