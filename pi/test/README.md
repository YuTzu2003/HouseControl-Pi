# 獨立硬體測試程式

這個資料夾內的程式彼此獨立，也不會匯入或呼叫專案其他程式、資料庫、API 或控制器函式。它們只使用所需的第三方硬體套件。

執行前請停止任何使用相同 GPIO 或 RFID 裝置的服務。

| 程式 | 用途 | GPIO.BOARD 腳位 |
| --- | --- | --- |
| `test_led.py` | RGB 燈泡／燈條 | 29、31、33 |
| `test_rfid.py` | MFRC522 RFID 與蜂鳴器 | 蜂鳴器 12 |
| `test_dht11.py` | DHT11 溫濕度 | 資料線 7 |
| `test_mqtt.py` | MQTT 發布／訂閱 | 無 GPIO |

```bash
# 燈泡：暖白、50% 亮度、5 秒
python hardware_tests/test_led.py
python hardware_tests/test_led.py --color red --brightness 30 --seconds 10

# RFID（不測蜂鳴器可加 --no-beep）
python hardware_tests/test_rfid.py

# DHT11（建議讀取間隔至少 2 秒）
python hardware_tests/test_dht11.py --count 5 --interval 2

# MQTT；可用 --host、--port、--username、--password 修改連線設定
python hardware_tests/test_mqtt.py
```

若使用專案的 uv 虛擬環境，將上述 `python` 改為 `uv run python` 即可。
