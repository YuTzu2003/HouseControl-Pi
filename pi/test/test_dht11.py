import argparse
import time
import RPi.GPIO as GPIO

DHT_PIN = 7

def read_dht11():
    GPIO.setup(DHT_PIN, GPIO.OUT)
    GPIO.output(DHT_PIN, GPIO.LOW)
    time.sleep(0.02)
    GPIO.setup(DHT_PIN, GPIO.IN)
    pulses, start, previous = [], time.perf_counter_ns(), GPIO.input(DHT_PIN)
    while time.perf_counter_ns() - start < 10_000_000:
        state = GPIO.input(DHT_PIN)
        if state != previous:
            pulses.append((state, time.perf_counter_ns()))
            previous = state
    bits = []
    for index in range(1, len(pulses) - 1):
        state, timestamp = pulses[index]
        if state == GPIO.HIGH:
            duration_us = (pulses[index + 1][1] - timestamp) / 1000
            if 15 < duration_us < 110:
                bits.append(1 if duration_us > 50 else 0)
    if len(bits) == 41:
        bits = bits[1:]
    if len(bits) != 40:
        return None
    data = []
    for index in range(0, 40, 8):
        value = 0
        for bit in bits[index:index + 8]:
            value = (value << 1) | bit
        data.append(value)
    if sum(data[:4]) & 0xFF != data[4]:
        return None
    return data[2] + data[3] / 10, data[0] + data[1] / 10


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=1)
    parser.add_argument("--interval", type=float, default=2)
    args = parser.parse_args()
    if args.count < 1 or args.interval < 0:
        parser.error("count 至少為 1，interval 不可小於 0")
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BOARD)
    try:
        for index in range(args.count):
            reading = read_dht11()
            if reading is None:
                print(f"第 {index + 1} 次：讀取失敗")
            else:
                temperature, humidity = reading
                print(f"第 {index + 1} 次：溫度 {temperature:.1f} °C，濕度 {humidity:.1f} %")
            if index < args.count - 1:
                time.sleep(args.interval)
    finally:
        GPIO.cleanup()


if __name__ == "__main__":
    main()
