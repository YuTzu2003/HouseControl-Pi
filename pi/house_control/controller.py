import json
import os
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path

import paho.mqtt.client as mqtt
import RPi.GPIO as GPIO

from .sensor import read_dht11
from .light import LEDService, TOPIC_SET as LIGHT_TOPIC

MQTT_HOST = "127.0.0.1"
MQTT_PORT = 1883
TOPIC_DHT = "house/dht11/reading"
TOPIC_SCENE_EXECUTE = "house/scene/execute"
TOPIC_SCENE_RESULT = "house/scene/result"
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
        last_triggered_at TEXT, start_time TEXT, end_time TEXT,
        start_action TEXT, end_action TEXT, start_mode TEXT, start_brightness REAL,
        end_mode TEXT, end_brightness REAL, scene_id INTEGER, last_result TEXT)""")
    # Keep databases created by earlier versions usable without data loss.
    for name, definition in (
        ("start_time", "TEXT"), ("end_time", "TEXT"),
        ("start_action", "TEXT"), ("end_action", "TEXT"),
        ("start_mode", "TEXT"), ("start_brightness", "REAL"),
        ("end_mode", "TEXT"), ("end_brightness", "REAL"),
        ("scene_id", "INTEGER"), ("last_result", "TEXT"),
    ):
        columns = {row["name"] for row in db.execute("PRAGMA table_info(automation_rules)")}
        if name not in columns:
            db.execute(f"ALTER TABLE automation_rules ADD COLUMN {name} {definition}")
    db.execute("""CREATE TABLE IF NOT EXISTS scenes (
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        actions TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        last_executed_at TEXT, last_result TEXT)""")
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
        rows = db.execute("SELECT * FROM automation_rules ORDER BY COALESCE(start_time, time), id").fetchall()
    return [_automation_dict(row) for row in rows]


def save_automation(rule, rule_id=None):
    start_time = rule.get("start_time") or rule.get("time")
    start_action = rule.get("start_action") or rule.get("action")
    if not start_time or not start_action:
        raise ValueError("必須提供開始時間與開始動作")
    days = sorted(set(rule.get("days", [])))
    if not days:
        raise ValueError("至少選擇一個執行星期")
    if any(day not in range(7) for day in days):
        raise ValueError("星期必須介於 0 到 6")
    if start_action == "scene" and not rule.get("scene_id"):
        raise ValueError("情境動作需要 scene_id")
    end_action = rule.get("end_action")
    if rule.get("end_time") and not end_action:
        raise ValueError("設定結束時間時也要提供結束動作")
    if end_action == "scene" and not rule.get("scene_id"):
        raise ValueError("情境動作需要 scene_id")
    payload = (
        rule["name"], start_time, json.dumps(days), start_action,
        int(rule.get("enabled", True)), rule.get("end_time"), start_action,
        end_action, rule.get("start_mode"), rule.get("start_brightness"),
        rule.get("end_mode"), rule.get("end_brightness"), rule.get("scene_id"),
    )
    with connection() as db:
        if rule_id is None:
            cursor = db.execute(
                """INSERT INTO automation_rules
                (name, time, days, action, enabled, last_triggered_at,
                 start_time, end_time, start_action, end_action, start_mode,
                 start_brightness, end_mode, end_brightness, scene_id, last_result)
                VALUES (?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)""",
                (payload[0], payload[1], payload[2], payload[3], payload[4],
                 payload[1], payload[5], payload[6], payload[7], payload[8],
                 payload[9], payload[10], payload[11], payload[12]),
            )
            rule_id = cursor.lastrowid
        else:
            updated = db.execute(
                """UPDATE automation_rules SET name=?, time=?, days=?, action=?, enabled=?,
                last_triggered_at=NULL, start_time=?, end_time=?, start_action=?, end_action=?,
                start_mode=?, start_brightness=?, end_mode=?, end_brightness=?, scene_id=?, last_result=NULL
                WHERE id=?""",
                (payload[0], payload[1], payload[2], payload[3], payload[4], payload[1],
                 payload[5], payload[6], payload[7], payload[8], payload[9], payload[10],
                 payload[11], payload[12], rule_id),
            )
            if updated.rowcount == 0:
                return None
        row = db.execute("SELECT * FROM automation_rules WHERE id = ?", (rule_id,)).fetchone()
    return _automation_dict(row) if row else None


def delete_automation(rule_id):
    with connection() as db:
        return db.execute("DELETE FROM automation_rules WHERE id = ?", (rule_id,)).rowcount > 0


def _dispatch_action(rule, prefix, publish_light, publish_scene):
    action = rule.get(f"{prefix}_action") or (rule.get("action") if prefix == "start" else None)
    if not action:
        return False
    if action == "scene":
        if publish_scene is None or not rule.get("scene_id"):
            raise ValueError("找不到要執行的情境")
        publish_scene(rule["scene_id"])
        return True
    command = {"on": action == "on"}
    mode = rule.get(f"{prefix}_mode")
    brightness = rule.get(f"{prefix}_brightness")
    if mode:
        command["mode"] = mode
    if brightness is not None:
        command["brightness"] = brightness
    publish_light(command)
    return True


def run_due_automations(publish_light, publish_scene=None, now=None):
    """Queue matching schedule events once per local minute."""
    if isinstance(publish_scene, datetime) and now is None:
        # Backwards-compatible with the previous (publish_light, now) API.
        now, publish_scene = publish_scene, None
    local_now = now or datetime.now().astimezone()
    minute = local_now.strftime("%H:%M")
    day = local_now.weekday()
    date_prefix = local_now.strftime("%Y-%m-%dT%H:%M")
    with connection() as db:
        rows = db.execute("SELECT * FROM automation_rules WHERE enabled = 1").fetchall()
        for row in rows:
            rule = _automation_dict(row)
            if day not in rule["days"]:
                continue
            events = []
            if rule["start_time"] == minute:
                events.append("start")
            if rule["end_time"] and rule["end_time"] == minute:
                events.append("end")
            for event in events:
                slot = f"{date_prefix}:{event}"
                if rule["last_triggered_at"] == slot:
                    continue
                try:
                    if _dispatch_action(rule, event, publish_light, publish_scene):
                        db.execute(
                            "UPDATE automation_rules SET last_triggered_at=?, last_result=? WHERE id=?",
                            (slot, "queued", rule["id"]),
                        )
                except Exception as error:
                    db.execute(
                        "UPDATE automation_rules SET last_triggered_at=?, last_result=? WHERE id=?",
                        (slot, f"error: {error}", rule["id"]),
                    )


def _automation_dict(row):
    rule = dict(row)
    rule["days"] = json.loads(rule["days"])
    rule["enabled"] = bool(rule["enabled"])
    rule["start_time"] = rule.get("start_time") or rule["time"]
    rule["start_action"] = rule.get("start_action") or rule["action"]
    return rule


def list_scenes():
    with connection() as db:
        rows = db.execute("SELECT * FROM scenes ORDER BY name, id").fetchall()
    return [_scene_dict(row) for row in rows]


def get_scene(scene_id):
    with connection() as db:
        row = db.execute("SELECT * FROM scenes WHERE id = ?", (scene_id,)).fetchone()
    return _scene_dict(row) if row else None


def save_scene(scene, scene_id=None):
    actions = scene.get("actions") or []
    if not actions:
        raise ValueError("情境至少需要一個設備動作")
    now = utc_now()
    encoded = json.dumps(actions, ensure_ascii=False)
    with connection() as db:
        if scene_id is None:
            cursor = db.execute(
                "INSERT INTO scenes (name, actions, enabled, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
                (scene["name"], encoded, int(scene.get("enabled", True)), now, now),
            )
            scene_id = cursor.lastrowid
        else:
            updated = db.execute(
                "UPDATE scenes SET name=?, actions=?, enabled=?, updated_at=? WHERE id=?",
                (scene["name"], encoded, int(scene.get("enabled", True)), now, scene_id),
            )
            if updated.rowcount == 0:
                return None
        row = db.execute("SELECT * FROM scenes WHERE id = ?", (scene_id,)).fetchone()
    return _scene_dict(row) if row else None


def delete_scene(scene_id):
    with connection() as db:
        return db.execute("DELETE FROM scenes WHERE id = ?", (scene_id,)).rowcount > 0


def update_scene_execution(scene_id, result):
    with connection() as db:
        db.execute(
            "UPDATE scenes SET last_executed_at=?, last_result=? WHERE id=?",
            (utc_now(), result, scene_id),
        )


def _scene_dict(row):
    scene = dict(row)
    scene["actions"] = json.loads(scene["actions"])
    scene["enabled"] = bool(scene["enabled"])
    return scene


def execute_scene(scene_id, request_id, led, music, publish_result):
    scene = get_scene(scene_id)
    if scene is None:
        result = {"ok": False, "scene_id": scene_id, "request_id": request_id, "error": "找不到情境"}
        publish_result(result)
        return result
    if not scene["enabled"]:
        result = {"ok": False, "scene_id": scene_id, "request_id": request_id, "error": "情境目前已停用"}
        update_scene_execution(scene_id, json.dumps(result, ensure_ascii=False))
        publish_result(result)
        return result
    results = []
    for index, action in enumerate(scene["actions"]):
        device = action.get("device")
        try:
            if device == "light":
                ok, error = led.apply_command(action)
            elif device == "music":
                if action.get("command", "play") == "stop":
                    music.stop()
                    ok, error = True, None
                else:
                    ok, error = music.play_url(action.get("url", ""))
            else:
                ok, error = False, f"不支援的設備：{device}"
        except Exception as error:
            ok, error = False, str(error)
        results.append({"index": index, "device": device, "ok": ok, "error": error})
    ok = all(item["ok"] for item in results)
    result = {
        "ok": ok, "scene_id": scene_id, "request_id": request_id,
        "results": results, "at": utc_now(),
    }
    update_scene_execution(scene_id, json.dumps(result, ensure_ascii=False))
    publish_result(result)
    return result


def _load_env_file():
    """讀取 house_control.env 到 os.environ，確保子程序也吃得到。"""
    candidates = [
        Path(__file__).resolve().parent.parent / "house_control.env",
        Path.cwd() / "house_control.env",
        Path.home() / "Desktop" / "pi" / "house_control.env",
    ]
    env_path = None
    for p in candidates:
        print(f"[env] 檢查：{p}  exists={p.is_file()}")
        if p.is_file():
            env_path = p
            break
    if env_path is None:
        print("[env] 所有路徑都找不到 env 檔，跳過")
        return
    print(f"[env] 使用：{env_path}")
    with open(env_path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, _, value = line.partition("=")
            key, value = key.strip(), value.strip()
            if key and value:
                os.environ[key] = value
                print(f"[env] 設定 {key}={value[:40]}{'…' if len(value) > 40 else ''}")


def main():
    _load_env_file()

    from .music import MusicService, TOPIC_PLAY, TOPIC_STOP
    from .rfid import RFIDService, TOPIC_BIND, TOPIC_STATUS
    from .youtube_player import (
        YouTubeService,
        TOPIC_PLAY as YT_TOPIC_PLAY,
        TOPIC_STOP as YT_TOPIC_STOP,
        TOPIC_PAUSE as YT_TOPIC_PAUSE,
        TOPIC_VOLUME as YT_TOPIC_VOLUME,
    )

    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2, client_id="pi4-house-control")
    rfid, led, music = RFIDService(client), LEDService(client), MusicService(client)
    youtube = YouTubeService(client)

    def publish_light(command):
        client.publish(LIGHT_TOPIC, json.dumps(command), qos=1)

    def publish_scene(scene_id):
        request_id = f"schedule-{scene_id}-{int(time.time())}"
        client.publish(TOPIC_SCENE_EXECUTE, json.dumps({"scene_id": scene_id, "request_id": request_id}), qos=1)

    def publish_scene_result(result):
        client.publish(TOPIC_SCENE_RESULT, json.dumps(result, ensure_ascii=False), qos=1)

    def on_connect(mqtt_client, userdata, flags, reason_code, properties):
        if reason_code != 0:
            print("MQTT連線失敗：", reason_code)
            return
        mqtt_client.subscribe([
            (TOPIC_BIND, 1), (LIGHT_TOPIC, 1), (TOPIC_PLAY, 1), (TOPIC_STOP, 1),
            (TOPIC_SCENE_EXECUTE, 1),
            (YT_TOPIC_PLAY, 1), (YT_TOPIC_STOP, 1), (YT_TOPIC_PAUSE, 1), (YT_TOPIC_VOLUME, 1),
        ])
        mqtt_client.publish(TOPIC_STATUS, json.dumps({"online": True, "at": utc_now()}), qos=1, retain=True)
        led.report()
        # 首次連線時就把 retained 狀態塞到 house/youtube/status，
        # App 一打開就能看到「尚未播放」而不是空白。
        youtube.publish_status()
        print("家庭控制器已連線 MQTT")

    def on_message(mqtt_client, userdata, message):
        try:
            payload = message.payload.decode("utf-8", errors="replace")
            if len(payload) > 300:
                payload = f"{payload[:300]}…"
            print(f"MQTT 收到：topic={message.topic} retained={message.retain} payload={payload}")
            if message.topic == TOPIC_BIND:
                rfid.handle_mqtt(message.payload, message.retain)
            elif message.topic == LIGHT_TOPIC:
                led.handle_mqtt(message.payload, message.retain)
            elif message.topic == TOPIC_PLAY:
                music.handle_play(message.payload, message.retain)
            elif message.topic == TOPIC_STOP:
                music.handle_stop(message.payload, message.retain)
            elif message.topic == YT_TOPIC_PLAY:
                youtube.handle_play(message.payload, message.retain)
            elif message.topic == YT_TOPIC_STOP:
                youtube.handle_stop(message.payload, message.retain)
            elif message.topic == YT_TOPIC_PAUSE:
                youtube.handle_pause(message.payload, message.retain)
            elif message.topic == YT_TOPIC_VOLUME:
                youtube.handle_volume(message.payload, message.retain)
            elif message.topic == TOPIC_SCENE_EXECUTE and not message.retain:
                try:
                    payload = json.loads(message.payload.decode("utf-8"))
                    result = execute_scene(
                        int(payload["scene_id"]),
                        str(payload.get("request_id", "")),
                        led,
                        music,
                        publish_scene_result,
                    )
                    print(f"情境執行完成：{result}")
                except (ValueError, TypeError, KeyError, UnicodeDecodeError, json.JSONDecodeError) as error:
                    publish_scene_result({"ok": False, "error": str(error), "at": utc_now()})
        except Exception:
            import logging
            logging.getLogger(__name__).exception("on_message handler %s failed", message.topic)

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
                run_due_automations(publish_light, publish_scene)
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
        youtube.stop()
        GPIO.output(12, GPIO.LOW)
        client.loop_stop()
        client.disconnect()
        GPIO.cleanup()


if __name__ == "__main__":
    main()
