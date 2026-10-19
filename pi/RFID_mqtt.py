import json
import re
import time
import RPi.GPIO as GPIO
from mfrc522 import SimpleMFRC522
from house_pi import bind_card, record_access, utc_now

TOPIC_BIND = "house/rfid/bind"
TOPIC_EVENT = "house/rfid/event"
TOPIC_STATUS = "house/rfid/status"
BUZZER_PIN = 12

class RFIDService:
    def __init__(self, client):
        self.client, self.pending_member, self.last_uid = client, None, None
        GPIO.setup(BUZZER_PIN, GPIO.OUT, initial=GPIO.LOW)
        self.reader = SimpleMFRC522()

    def publish(self, topic, data):
        self.client.publish(topic, json.dumps(data, ensure_ascii=False), qos=1)

    def handle_mqtt(self, payload, retained=False):
        if retained or len(payload) > 1024:
            return
        try:
            data = json.loads(payload.decode("utf-8"))
            member_id = self._text(data.get("member_id"), "member_id")
            member_name = self._text(data.get("member_name"), "member_name")
            if not re.fullmatch(r"[A-Za-z0-9@._:-]+", member_id):
                raise ValueError("member_id 僅能包含英數字與 @ . _ : -")
            self.pending_member = {"member_id": member_id, "member_name": member_name,
                                   "expires_at": time.monotonic() + 60}
            self.publish(TOPIC_EVENT, {"type": "bind_waiting", "member_id": member_id,
                "member_name": member_name, "expires_in": 60, "at": utc_now()})
        except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError) as error:
            self.publish(TOPIC_EVENT, {"type": "error", "message": str(error), "at": utc_now()})

    @staticmethod
    def _text(value, name):
        if not isinstance(value, str) or not value.strip() or len(value.strip()) > 100:
            raise ValueError(f"{name} 必須是 1～100 個字元的文字")
        return value.strip()

    def poll(self):
        uid = self.reader.read_id_no_block()
        if uid is not None and uid != self.last_uid:
            self.handle_card(str(uid))
        self.last_uid = uid

    def handle_card(self, uid):
        now = utc_now()
        if self.pending_member and time.monotonic() > self.pending_member["expires_at"]:
            self.publish(TOPIC_EVENT, {"type": "bind_expired", "at": now})
            self.pending_member = None
        if self.pending_member:
            member = self.pending_member
            bind_card(uid, member["member_id"], member["member_name"])
            self.pending_member = None
            self._beep(.25)
            self.publish(TOPIC_EVENT, {"type": "bound", "uid": uid, "member_id": member["member_id"],
                "member_name": member["member_name"], "at": now})
            return
        card = record_access(uid)
        if card:
            self._beep()
            event = {"type": "access_granted", "uid": uid, "member_id": card["member_id"],
                     "member_name": card["member_name"], "at": now}
        else:
            event = {"type": "access_denied", "uid": uid, "at": now}
        self.publish(TOPIC_EVENT, event)

    @staticmethod
    def _beep(duration=.15):
        GPIO.output(BUZZER_PIN, GPIO.HIGH)
        time.sleep(duration)
        GPIO.output(BUZZER_PIN, GPIO.LOW)
