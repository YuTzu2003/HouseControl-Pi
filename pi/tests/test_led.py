#!/usr/bin/env python3
"""獨立測試 RGB 燈泡；採 GPIO.BOARD 腳位 29、31、33。"""
import argparse
import time
import RPi.GPIO as GPIO

PINS = (29, 31, 33)
COLORS = {"red": (100, 0, 0), "green": (0, 100, 0), "blue": (0, 0, 100),
          "white": (100, 100, 100), "warm_white": (100, 65, 20), "off": (0, 0, 0)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--color", choices=COLORS, default="warm_white")
    parser.add_argument("--brightness", type=float, default=50)
    parser.add_argument("--seconds", type=float, default=5)
    args = parser.parse_args()
    if not 0 <= args.brightness <= 100 or args.seconds < 0:
        parser.error("brightness 必須為 0～100，seconds 不可小於 0")
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    pwms = []
    try:
        for pin in PINS:
            GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)
            pwm = GPIO.PWM(pin, 1000)
            pwm.start(0)
            pwms.append(pwm)
        for pwm, value in zip(pwms, COLORS[args.color]):
            pwm.ChangeDutyCycle(value * args.brightness / 100)
        print(f"燈光：{args.color}，亮度：{args.brightness:g}%")
        if args.seconds:
            time.sleep(args.seconds)
    except KeyboardInterrupt:
        print("\n已中止")
    finally:
        for pwm in pwms:
            pwm.ChangeDutyCycle(0)
            pwm.stop()
        GPIO.cleanup(PINS)
        print("燈光已關閉。")


if __name__ == "__main__":

    main()