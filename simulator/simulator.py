import json, random, sys, threading, time
from datetime import datetime, timedelta, timezone
import paho.mqtt.client as mqtt

BROKER, PORT = "localhost", 1883
CENTERS = [(36.9541, 8.7580), (36.9565, 8.7615)]   # 2 habitual zones, ~400 m apart
TRACKERS = ["T001", "T002", "T003"]

class Cow:
    def __init__(self, tid):
        self.tid = tid
        self.center = random.choice(CENTERS)
        self.lat, self.lon = self.center
        self.battery = 100.0
        self.mode = "normal"   # normal | escape | still | rush

    def step(self):
        if self.mode == "escape":
            self.lat += 0.0004; self.lon += 0.0004; speed, act = 3.0, 0.6
        elif self.mode == "still":
            speed, act = 0.0, 0.01
        elif self.mode == "rush":
            self.lat += random.uniform(-0.0005, 0.0005)
            self.lon += random.uniform(-0.0005, 0.0005)
            speed, act = random.uniform(12, 18), 0.95
        else:
            if random.random() < 0.002:
                self.center = random.choice(CENTERS)
            self.lat += (self.center[0] - self.lat) * 0.1 + random.gauss(0, 0.0001)
            self.lon += (self.center[1] - self.lon) * 0.1 + random.gauss(0, 0.0001)
            speed, act = abs(random.gauss(1.0, 0.5)), min(1.0, abs(random.gauss(0.3, 0.15)))
        self.battery = max(0.0, self.battery - 0.002)
        return speed, act

def message(cow, ts):
    speed, act = cow.step()
    return {"tracker_id": cow.tid, "ts": ts.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "lat": round(cow.lat, 6), "lon": round(cow.lon, 6),
            "speed": round(speed, 2), "activity": round(act, 2),
            "battery": round(cow.battery)}

def main():
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
    client.connect(BROKER, PORT); client.loop_start()
    cows = {t: Cow(t) for t in TRACKERS}
    def publish(cow, ts):
        client.publish(f"livestock/{cow.tid}/uplink", json.dumps(message(cow, ts)), qos=1)
    if len(sys.argv) == 3 and sys.argv[1] == "history":      # python simulator.py history 14
        end = datetime.now(timezone.utc)
        t = end - timedelta(days=int(sys.argv[2]))
        while t < end:
            for c in cows.values(): publish(c, t)
            t += timedelta(minutes=5); time.sleep(0.01)
    else:                                                     # python simulator.py
        def commands():
            while True:
                try: tid, mode = input("> ").split()          # e.g. T001 escape
                except ValueError: continue
                if tid in cows: cows[tid].mode = mode
        threading.Thread(target=commands, daemon=True).start()
        while True:
            for c in cows.values(): publish(c, datetime.now(timezone.utc))
            time.sleep(5)

main()