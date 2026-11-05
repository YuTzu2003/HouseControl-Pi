import json
import math
import os
import RPi.GPIO as GPIO

TOPIC_SET = "house/room/light/set"
TOPIC_STATE = "house/room/light/state"
PINS = (29, 31, 33)
COLORS = {
    "warm_yellow": (100, 65, 0),
    "warm_white": (100, 80, 45),
    "natural_white": (100, 95, 75),
    "cool_white": (70, 85, 100),
}


def _channel_order():
    order = os.environ.get("HOUSE_CONTROL_LED_CHANNEL_ORDER", "rgb").strip().lower()
    if sorted(order) != ["b", "g", "r"]:
        print(f"LED 通道順序無效：{order}；使用預設 rgb")
        return "rgb"
    return order


CHANNEL_ORDER = _channel_order()
COMMON_ANODE = os.environ.get("HOUSE_CONTROL_LED_COMMON_ANODE", "false").strip().lower() in {"1", "true", "yes", "on",}


def _off_duty_cycle():
    return 100 if COMMON_ANODE else 0


class LEDService:
    def __init__(self, client):
        self.client = client
        self.state = {"on": False, "mode": "warm_white", "brightness": 100}
        self.pwms = []
        for pin in PINS:
            GPIO.setup(pin, GPIO.OUT, initial=GPIO.HIGH if COMMON_ANODE else GPIO.LOW)
            pwm = GPIO.PWM(pin, 1000)
            pwm.start(_off_duty_cycle())
            self.pwms.append(pwm)
        print(f"LED 設定：腳位={PINS}，通道順序={CHANNEL_ORDER}，"f"共陽極={'是' if COMMON_ANODE else '否'}")

    def handle_mqtt(self, payload, retained=False):
        if retained or len(payload) > 1024:
            return
        try:
            data = json.loads(payload.decode("utf-8"))
            print(f"燈光收到 MQTT 指令：{data}")
            ok, error = self.apply_command(data)
            if ok:
                print(f"燈光已套用：{self.state}")
            else:
                print(f"燈光指令失敗：{error}")
        except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError) as error:
            print(f"燈光指令失敗：{error}")

    def apply_command(self, data):
        try:
            updated = self.state.copy()
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
                if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 100:
                    raise ValueError("亮度必須介於 0～100")
                updated["brightness"] = value
            self.state = updated
            self.apply()
            self.report()
            return True, None
        except Exception as error:
            return False, str(error)

    def apply(self):
        scale = self.state["brightness"] / 100 if self.state["on"] else 0
        red, green, blue = COLORS[self.state["mode"]]
        self.apply_rgb(red, green, blue, scale=scale)

    def apply_rgb(self, red, green, blue, *, scale=1):
        channels = {"r": red, "g": green, "b": blue}
        for pwm, channel in zip(self.pwms, CHANNEL_ORDER):
            duty_cycle = channels[channel] * scale
            pwm.ChangeDutyCycle(100 - duty_cycle if COMMON_ANODE else duty_cycle)

    def report(self):
        self.client.publish(TOPIC_STATE, json.dumps(self.state), qos=1, retain=True)

    def close(self):
        for pwm in self.pwms:
            pwm.ChangeDutyCycle(_off_duty_cycle())
            pwm.stop()