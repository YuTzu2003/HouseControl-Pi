import time
import RPi.GPIO as GPIO
from mfrc522 import SimpleMFRC522

BUZZER_PIN = 12

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BOARD)
GPIO.setup(BUZZER_PIN, GPIO.OUT, initial=GPIO.LOW)

reader = SimpleMFRC522()
last_uid = None

try:
    print("請感應 RFID 卡片...")
    while True:
        uid = reader.read_id_no_block()
        if uid is not None:
            if uid != last_uid:
                print(f"讀取成功！UID: {uid}")

                GPIO.output(BUZZER_PIN, GPIO.HIGH)
                time.sleep(0.15)
                GPIO.output(BUZZER_PIN, GPIO.LOW)
            last_uid = uid
        else:
            last_uid = None
        time.sleep(0.1)

except KeyboardInterrupt:
    print("程式結束")

finally:
    GPIO.output(BUZZER_PIN, GPIO.LOW)
    GPIO.cleanup()