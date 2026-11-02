import time
import RPi.GPIO as GPIO

DHT_PIN = 7

def read_dht11():
    GPIO.setup(DHT_PIN, GPIO.OUT)
    GPIO.output(DHT_PIN, GPIO.LOW)
    time.sleep(0.02)
    GPIO.setup(DHT_PIN, GPIO.IN)

    pulses = []
    start = time.perf_counter_ns()
    last_state = GPIO.input(DHT_PIN)
    while time.perf_counter_ns() - start < 10_000_000:
        state = GPIO.input(DHT_PIN)
        if state != last_state:
            pulses.append((state, time.perf_counter_ns()))
            last_state = state
    bits = []
    for i in range(1, len(pulses) - 1):
        state, timestamp = pulses[i]
        if state == GPIO.HIGH:
            duration_us = (pulses[i + 1][1] - timestamp) / 1000
            if 15 < duration_us < 110:
                bits.append(1 if duration_us > 50 else 0)
    if len(bits) == 41:
        bits = bits[1:]
    if len(bits) != 40:
        return None
    data = []
    for i in range(0, 40, 8):
        value = 0
        for bit in bits[i : i + 8]:
            value = (value << 1) | bit
        data.append(value)
    if sum(data[:4]) & 0xFF != data[4]:
        return None
    return data[2] + data[3] / 10, data[0] + data[1] / 10
