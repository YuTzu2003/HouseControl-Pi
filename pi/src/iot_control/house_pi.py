import json
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path
import paho.mqtt.client as mqtt
import RPi.GPIO as GPIO
from .dht11_conn import read_dht11
from .led_mqtt import LEDService, TOPIC_SET as LIGHT_TOPIC

MQTT_HOST = "127.0.0.1"
MQTT_PORT = 1883
MQTT_USER = "houseapp"
MQTT_PASSWORD = "123456"
TOPIC_DHT = "house/dht11/reading"
DHT_INTERVAL_SECONDS = 30 * 60
DATABASE_PATH = Path.cwd() / "house-pi.db"

def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")

def connection():
    db = sqlite3.connect(DATABASE_PATH)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA journal_mode=WAL")
    db.execute("""CREATE TABLE IF NOT EXISTS rfid_cards (
        uid TEXT PRIMARY KEY, member_id TEXT NOT NULL, member_name TEXT NOT NULL,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, last_seen_at TEXT)""")
    db.execute("""CREATE TABLE IF NOT EXISTS rfid_access_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT NOT NULL, member_id TEXT,
        member_name TEXT, granted INTEGER NOT NULL, scanned_at TEXT NOT NULL)""")
    db.execute("""CREATE TABLE IF NOT EXISTS dht11_readings (
        id INTEGER PRIMARY KEY AUTOINCREMENT, temperature REAL NOT NULL,
        humidity REAL NOT NULL, recorded_at TEXT NOT NULL)""")
    db.execute("""CREATE TABLE IF NOT EXISTS automation_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, time TEXT NOT NULL,
        days TEXT NOT NULL, action TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1,
        last_triggered_at TEXT)""")
    db.commit()
    return db

def bind_card(uid, member_id, member_name):
    now = utc_now()
    with connection() as db:
        db.execute("""INSERT INTO rfid_cards (uid, member_id, member_name, created_at, updated_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(uid) DO UPDATE SET member_id=excluded.member_id,
            member_name=excluded.member_name, updated_at=excluded.updated_at, last_seen_at=excluded.last_seen_at""",
            (uid, member_id, member_name, now, now, now))
    return get_card(uid)

def get_card(uid):
    with connection() as db:
        row = db.execute("SELECT * FROM rfid_cards WHERE uid = ?", (uid,)).fetchone()
    return dict(row) if row else None

def list_cards(member_id=None):
    with connection() as db:
        query, args = "SELECT * FROM rfid_cards", ()
        if member_id:
            query += " WHERE member_id = ?"
            args = (member_id,)
        rows = db.execute(query + " ORDER BY member_name, uid", args).fetchall()
    return [dict(row) for row in rows]

def record_access(uid):
    now = utc_now()
    with connection() as db:
        row = db.execute("SELECT * FROM rfid_cards WHERE uid = ?", (uid,)).fetchone()
        if row is None:
            db.execute("INSERT INTO rfid_access_logs (uid, granted, scanned_at) VALUES (?, 0, ?)", (uid, now))
            return None
        db.execute("UPDATE rfid_cards SET last_seen_at = ? WHERE uid = ?", (now, uid))
        db.execute("""INSERT INTO rfid_access_logs (uid, member_id, member_name, granted, scanned_at)
            VALUES (?, ?, ?, 1, ?)""", (uid, row["member_id"], row["member_name"], now))
    return get_card(uid)

def list_access_logs(limit=100):
    with connection() as db:
        rows = db.execute("SELECT * FROM rfid_access_logs ORDER BY id DESC LIMIT ?", (limit,)).fetchall()
    return [dict(row) for row in rows]

def save_dht11_reading(temperature, humidity):
    reading = {"temperature": temperature, "humidity": humidity, "recorded_at": utc_now()}
    with connection() as db:
        db.execute("INSERT INTO dht11_readings (temperature, humidity, recorded_at) VALUES (?, ?, ?)",
                   (temperature, humidity, reading["recorded_at"]))
    return reading

def list_dht11_readings(limit=48):
    with connection() as db:
        rows = db.execute("SELECT * FROM dht11_readings ORDER BY id DESC LIMIT ?", (limit,)).fetchall()
    return [dict(row) for row in rows]

def list_automations():
    with connection() as db:
        rows = db.execute("SELECT * FROM automation_rules ORDER BY time, id").fetchall()
    return [_automation_dict(row) for row in rows]

def save_automation(rule, rule_id=None):
    days = json.dumps(sorted(set(rule["days"])))
    with connection() as db:
        if rule_id is None:
            cursor = db.execute(
                "INSERT INTO automation_rules (name, time, days, action, enabled) VALUES (?, ?, ?, ?, ?)",
                (rule["name"], rule["time"], days, rule["action"], int(rule.get("enabled", True))),
            )
            rule_id = cursor.lastrowid
        else:
            db.execute(
                "UPDATE automation_rules SET name=?, time=?, days=?, action=?, enabled=? WHERE id=?",
                (rule["name"], rule["time"], days, rule["action"], int(rule.get("enabled", True)), rule_id),
            )
        row = db.execute("SELECT * FROM automation_rules WHERE id = ?", (rule_id,)).fetchone()
    return _automation_dict(row) if row else None


def delete_automation(rule_id):
    with connection() as db:
        return db.execute("DELETE FROM automation_rules WHERE id = ?", (rule_id,)).rowcount > 0


def run_due_automations(publish_light, now=None):
    local_now = now or datetime.now().astimezone()
    slot = local_now.strftime("%Y-%m-%dT%H:%M")
    with connection() as db:
        rows = db.execute("SELECT * FROM automation_rules WHERE enabled = 1 AND time = ?", (local_now.strftime("%H:%M"),)).fetchall()
        for row in rows:
            rule = _automation_dict(row)
            if local_now.weekday() not in rule["days"] or rule["last_triggered_at"] == slot:
                continue
            publish_light(rule["action"] == "on")
            db.execute("UPDATE automation_rules SET last_triggered_at = ? WHERE id = ?", (slot, rule["id"]))


def _automation_dict(row):
    rule = dict(row)
    rule["days"] = json.loads(rule["days"])
    rule["enabled"] = bool(rule["enabled"])
    return rule


def main():
    from .rfid_mqtt import RFIDService, TOPIC_BIND, TOPIC_STATUS
    from .music_mqtt import MusicService, TOPIC_PLAY, TOPIC_STOP
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2, client_id="pi4-house-control")
    client.username_pw_set(MQTT_USER, MQTT_PASSWORD)
    rfid, led, music = RFIDService(client), LEDService(client), MusicService(client)

    def on_connect(mqtt_client, userdata, flags, reason_code, properties):
        if reason_code != 0:
            print("MQTT連線失敗：", reason_code)
            return
        mqtt_client.subscribe([(TOPIC_BIND, 1), (LIGHT_TOPIC, 1), (TOPIC_PLAY, 1), (TOPIC_STOP, 1)])
        mqtt_client.publish(TOPIC_STATUS, json.dumps({"online": True, "at": utc_now()}), qos=1, retain=True)
        led.report()
        print("家庭控制器已連線 MQTT")

    def on_message(mqtt_client, userdata, message):
        if message.topic == TOPIC_BIND:
            rfid.handle_mqtt(message.payload, message.retain)
        elif message.topic == LIGHT_TOPIC:
            led.handle_mqtt(message.payload, message.retain)
        elif message.topic == TOPIC_PLAY:
            music.handle_play(message.payload, message.retain)
        elif message.topic == TOPIC_STOP:
            music.handle_stop(message.payload, message.retain)

    client.on_connect, client.on_message = on_connect, on_message
    client.reconnect_delay_set(1, 30)
    client.connect_async(MQTT_HOST, MQTT_PORT, keepalive=30)
    client.loop_start()
    next_dht_at = time.monotonic()
    next_automation_at = time.monotonic()
    try:
        while True:
            rfid.poll()
            if time.monotonic() >= next_automation_at:
                next_automation_at = time.monotonic() + 10
                run_due_automations(lambda on: client.publish(LIGHT_TOPIC, json.dumps({"on": on}), qos=1))
            if time.monotonic() >= next_dht_at:
                next_dht_at = time.monotonic() + DHT_INTERVAL_SECONDS
                result = read_dht11()
                if result is None:
                    print("溫溼度讀取失敗，本次不寫入資料庫")
                else:
                    temperature, humidity = result
                    reading = save_dht11_reading(temperature, humidity)
                    client.publish(TOPIC_DHT, json.dumps(reading), qos=1, retain=True)
                    print("溫溼度：", reading)
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("家庭控制器結束")
    finally:
        led.close()
        music.stop()
        GPIO.output(12, GPIO.LOW)
        client.loop_stop()
        client.disconnect()
        GPIO.cleanup()
