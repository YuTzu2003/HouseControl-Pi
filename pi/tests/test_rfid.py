#!/usr/bin/env python3
"""獨立測試 MFRC522 RFID，按 Ctrl+C 結束。"""
import argparse
import time
import RPi.GPIO as GPIO
from mfrc522 import SimpleMFRC522

BUZZER_PIN = 12  # GPIO.BOARD


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-beep", action="store_true")
    args = parser.parse_args()
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    if not args.no_beep:
        GPIO.setup(BUZZER_PIN, GPIO.OUT, initial=GPIO.LOW)
    reader, last_uid = SimpleMFRC522(), None
    print("請將 RFID 卡靠近讀卡機…")
    try:
        while True:
            uid = reader.read_id_no_block()
            if uid is not None and uid != last_uid:
                print(f"讀到卡片 UID：{uid}")
                if not args.no_beep:
                    GPIO.output(BUZZER_PIN, GPIO.HIGH)
                    time.sleep(0.15)
                    GPIO.output(BUZZER_PIN, GPIO.LOW)
            last_uid = uid
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n已結束 RFID 測試")
    finally:
        if not args.no_beep:
            GPIO.output(BUZZER_PIN, GPIO.LOW)
        GPIO.cleanup()


if __name__ == "__main__":
    main()