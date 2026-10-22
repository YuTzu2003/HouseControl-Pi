import asyncio
from pathlib import Path
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel, Field
from iot_control.house_pi import delete_automation, get_card, list_access_logs, list_automations, list_cards, list_dht11_readings, save_automation
from iot_control.config import LIVE_FRAME_PATH, RECORDINGS_DIR

app = FastAPI(title="IOT Control RFID API", version="1.0.0")
class Card(BaseModel):
    uid: str
    member_id: str
    member_name: str
    created_at: str
    updated_at: str
    last_seen_at: str | None

class DHT11Reading(BaseModel):
    id: int
    temperature: float
    humidity: float
    recorded_at: str

class AutomationRule(BaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=80)
    time: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    days: list[int] = Field(min_length=1)
    action: str = Field(pattern=r"^(on|off)$")
    enabled: bool = True
    last_triggered_at: str | None = None

@app.get("/health")
def health():
    return {"status": "ok"}


async def live_camera_frames():
    """Send the newest JPEG repeatedly without opening the webcam a second time."""
    while True:
        try:
            frame = LIVE_FRAME_PATH.read_bytes()
            yield b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + frame + b"\r\n"
        except FileNotFoundError:
            pass
        await asyncio.sleep(0.2)


@app.get("/camera/live.mjpg")
async def live_camera():
    return StreamingResponse(
        live_camera_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame",
        headers={"Cache-Control": "no-store"},
    )


@app.get("/camera/live.jpg")
def live_camera_frame():
    if not LIVE_FRAME_PATH.is_file():
        raise HTTPException(status_code=503, detail="Camera is starting")
    return FileResponse(LIVE_FRAME_PATH, media_type="image/jpeg", headers={"Cache-Control": "no-store"})


@app.get("/camera/recordings")
def recordings():
    return [
        {"name": file.name, "size": file.stat().st_size, "recorded_at": file.stem}
        for file in sorted(RECORDINGS_DIR.glob("*.mp4"), reverse=True)
    ]


@app.get("/camera/recordings/{name}")
def recording(name: str):
    file = RECORDINGS_DIR / Path(name).name
    if file.suffix != ".mp4" or not file.is_file():
        raise HTTPException(status_code=404, detail="Recording not found")
    return FileResponse(file, media_type="video/mp4", filename=file.name)


@app.get("/rfid/cards", response_model=list[Card])
def cards(member_id: str | None = Query(default=None, max_length=100)):
    """列出全部卡片，或以 member_id 過濾。"""
    return list_cards(member_id)


@app.get("/rfid/cards/{uid}", response_model=Card)
def card(uid: str):
    result = get_card(uid)
    if result is None:
        raise HTTPException(status_code=404, detail="找不到此 RFID 卡片")
    return result

@app.get("/rfid/access-logs")
def access_logs(limit: int = Query(default=100, ge=1, le=500)):
    return list_access_logs(limit)

@app.get("/dht11/readings", response_model=list[DHT11Reading])
def dht11_readings(limit: int = Query(default=48, ge=1, le=500)):
    return list_dht11_readings(limit)

@app.get("/automations", response_model=list[AutomationRule])
def automations(): return list_automations()

@app.post("/automations", response_model=AutomationRule)
def create_automation(rule: AutomationRule): return save_automation(rule.model_dump())

@app.put("/automations/{rule_id}", response_model=AutomationRule)
def update_automation(rule_id: int, rule: AutomationRule):
    result = save_automation(rule.model_dump(), rule_id)
    if result is None: raise HTTPException(status_code=404, detail="找不到自動化規則")
    return result

@app.delete("/automations/{rule_id}", status_code=204)
def remove_automation(rule_id: int):
    if not delete_automation(rule_id): raise HTTPException(status_code=404, detail="找不到自動化規則")
