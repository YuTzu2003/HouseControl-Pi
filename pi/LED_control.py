import json
import math
import RPi.GPIO as GPIO
import paho.mqtt.client as mqtt

MQTT_HOST = "127.0.0.1"
MQTT_USER = "houseapp"
MQTT_PASSWORD = "123456"
TOPIC_SET = "house/room/light/set"
TOPIC_STATE = "house/room/light/state"

PINS = (29, 31, 33)

COLORS = {
    "warm_yellow": (100, 30, 0),
    "warm_white": (100, 65, 20),
    "natural_white": (100, 85, 70),
    "cool_white": (75, 85, 100),
}

state = {
    "on": False,
    "mode": "warm_white",
    "brightness": 100,
}
pwms = []


def update_light():
    rgb = COLORS[state["mode"]]
    scale = state["brightness"] / 100 if state["on"] else 0
    for pwm, value in zip(pwms, rgb):
        pwm.ChangeDutyCycle(value * scale)

def report(client):
    client.publish(TOPIC_STATE,json.dumps(state),qos=1,retain=True,)

def on_connect(client, userdata, flags, reason_code, properties):
    if reason_code == 0:
        client.subscribe(TOPIC_SET, qos=1)
        report(client)
        print("MQTT 已連線，等待手機控制")
    else:
        print(reason_code)


def on_message(client, userdata, message):
    if message.retain or len(message.payload) > 1024:
        return

    try:
        data = json.loads(message.payload)
        updated = state.copy()

        if "on" in data:
            if type(data["on"]) is not bool:
                raise ValueError("on 必須是 true 或 false")
            updated["on"] = data["on"]

        if "mode" in data:
            if not isinstance(data["mode"], str) or data["mode"] not in COLORS:
                raise ValueError("不支援的燈光模式")
            updated["mode"] = data["mode"]

        if "brightness" in data:
            value = data["brightness"]
            if (type(value) not in (int, float)or not math.isfinite(value) or not 0 <= value <= 100):
                raise ValueError("亮度必須介於 0～100")
            updated["brightness"] = value
        state.update(updated)
        update_light()
        report(client)
        print("燈光設定：", state)

    except (ValueError, TypeError, UnicodeError) as error:
        print("指令錯誤：", error)

client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2,client_id="pi4-light",)
client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
client.on_connect = on_connect
client.on_message = on_message
client.reconnect_delay_set(1, 30)

try:
    GPIO.setmode(GPIO.BOARD)
    for pin in PINS:
        GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)
        pwm = GPIO.PWM(pin, 1000)
        pwm.start(0)
        pwms.append(pwm)
    client.connect_async(MQTT_HOST, 1883, keepalive=30)
    client.loop_forever(retry_first_connection=True)

except KeyboardInterrupt:
    print("\n程式結束")

finally:
    for pwm in pwms:
        pwm.ChangeDutyCycle(0)
        pwm.stop()
    client.disconnect()
    GPIO.cleanup(list(PINS))