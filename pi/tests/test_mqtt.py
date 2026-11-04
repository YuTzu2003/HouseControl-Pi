#!/usr/bin/env python3
"""獨立 MQTT 發布／訂閱測試。"""
import argparse
import os
import sys
import time
from uuid import uuid4
import paho.mqtt.client as mqtt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=os.getenv("MQTT_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("MQTT_PORT", "1883")))
    parser.add_argument("--username", default=os.getenv("MQTT_USER", "houseapp"))
    parser.add_argument("--password", default=os.getenv("MQTT_PASSWORD", "123456"))
    parser.add_argument("--topic", default="hardware/test")
    parser.add_argument("--message", default="MQTT test OK")
    parser.add_argument("--timeout", type=float, default=5)
    args = parser.parse_args()
    received = False
    client = mqtt.Client(callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
                         client_id=f"hardware-test-{uuid4().hex[:8]}")
    client.username_pw_set(args.username, args.password)

    def on_connect(mqtt_client, _userdata, _flags, reason_code, _properties):
        if reason_code == 0:
            mqtt_client.subscribe(args.topic, qos=1)
            mqtt_client.publish(args.topic, args.message, qos=1)
            print(f"已發佈至 {args.topic!r}，等待接收…")
        else:
            print(f"MQTT 連線失敗：{reason_code}", file=sys.stderr)

    def on_message(_client, _userdata, message):
        nonlocal received
        print(f"已收到：{message.topic!r} -> {message.payload.decode(errors='replace')}")
        received = True

    client.on_connect, client.on_message = on_connect, on_message
    try:
        client.connect(args.host, args.port, keepalive=10)
        client.loop_start()
        deadline = time.monotonic() + args.timeout
        while not received and time.monotonic() < deadline:
            time.sleep(0.05)
    except OSError as error:
        print(f"無法連線至 {args.host}:{args.port}：{error}", file=sys.stderr)
        raise SystemExit(1) from error
    finally:
        client.loop_stop()
        client.disconnect()
    if not received:
        print("逾時：未收到測試訊息。", file=sys.stderr)
        raise SystemExit(1)
    print("MQTT 測試成功。")


if __name__ == "__main__":
    main()