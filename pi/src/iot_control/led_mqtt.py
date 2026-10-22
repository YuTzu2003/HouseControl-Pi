import json
import math
import RPi.GPIO as GPIO

TOPIC_SET = "house/room/light/set"
TOPIC_STATE = "house/room/light/state"
PINS = (29, 31, 33)
COLORS = {"warm_yellow": (100, 30, 0), "warm_white": (100, 65, 20), "natural_white": (100, 85, 70), "cool_white": (75, 85, 100)}


class LEDService:
    def __init__(self, client):
        self.client = client
        self.state = {"on": False, "mode": "warm_white", "brightness": 100}
        self.pwms = []
        for pin in PINS:
            GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)
            pwm = GPIO.PWM(pin, 1000)
            pwm.start(0)
            self.pwms.append(pwm)

    def handle_mqtt(self, payload, retained=False):
        if retained or len(payload) > 1024:
            return
        try:
            data, updated = json.loads(payload.decode("utf-8")), self.state.copy()
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
        except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError) as error:
            print(error)

    def apply(self):
        scale = self.state["brightness"] / 100 if self.state["on"] else 0
        for pwm, value in zip(self.pwms, COLORS[self.state["mode"]]):
            pwm.ChangeDutyCycle(value * scale)

    def report(self):
        self.client.publish(TOPIC_STATE, json.dumps(self.state), qos=1, retain=True)

    def close(self):
        for pwm in self.pwms:
            pwm.ChangeDutyCycle(0)
            pwm.stop()
