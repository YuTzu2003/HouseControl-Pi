import asyncio
from pathlib import Path
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse, Response, StreamingResponse
from typing import Literal
from pydantic import BaseModel, Field, model_validator
from house_control.controller import (delete_automation,delete_scene,get_card,list_access_logs,list_automations,list_cards,
    list_dht11_readings,list_scenes,save_automation,save_scene,)
from house_control.config import LIVE_FRAME_PATH, RECORDINGS_DIR

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
    time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    days: list[int] = Field(min_length=1)
    action: Literal["on", "off", "scene"] | None = None
    enabled: bool = True
    start_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    end_time: str | None = Field(default=None, pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    start_action: Literal["on", "off", "scene"] | None = None
    end_action: Literal["on", "off", "scene"] | None = None
    start_mode: Literal["warm_yellow", "warm_white", "natural_white", "cool_white"] | None = None
    end_mode: Literal["warm_yellow", "warm_white", "natural_white", "cool_white"] | None = None
    start_brightness: float | None = Field(default=None, ge=0, le=100)
    end_brightness: float | None = Field(default=None, ge=0, le=100)
    scene_id: int | None = Field(default=None, ge=1)
    last_triggered_at: str | None = None
    last_result: str | None = None

    @model_validator(mode="after")
    def validate_schedule(self):
        start_time = self.start_time or self.time
        start_action = self.start_action or self.action
        if start_time is None or start_action is None:
            raise ValueError("需要開始時間與開始動作")
        if not all(day in range(7) for day in self.days):
            raise ValueError("星期必須介於 0 到 6")
        if self.end_time and self.end_action is None:
            raise ValueError("設定結束時間時也要提供結束動作")
        if (start_action == "scene" or self.end_action == "scene") and self.scene_id is None:
            raise ValueError("情境動作需要 scene_id")
        return self


class SceneAction(BaseModel):
    device: Literal["light", "music"]
    on: bool | None = None
    mode: Literal["warm_yellow", "warm_white", "natural_white", "cool_white"] | None = None
    brightness: float | None = Field(default=None, ge=0, le=100)
    command: Literal["play", "stop"] = "play"
    url: str | None = Field(default=None, max_length=2048)

    @model_validator(mode="after")
    def validate_action(self):
        if self.device == "light" and self.on is None and self.mode is None and self.brightness is None:
            raise ValueError("燈光動作至少需要設定開關、模式或亮度")
        if self.device == "music" and self.command == "play" and not self.url:
            raise ValueError("播放音樂需要 YouTube 連結")
        return self


class Scene(BaseModel):
    id: int | None = None
    name: str = Field(min_length=1, max_length=80)
    actions: list[SceneAction] = Field(min_length=1, max_length=20)
    enabled: bool = True
    created_at: str | None = None
    updated_at: str | None = None
    last_executed_at: str | None = None
    last_result: str | None = None

@app.get("/health")
def health():
    return {"status": "ok"}


async def live_camera_frames():
    while True:
        try:
            frame = LIVE_FRAME_PATH.read_bytes()
            yield b"--frame\r\nContent-Type: image/jpeg\r\n\r\n" + frame + b"\r\n"
        except FileNotFoundError:
            pass
        await asyncio.sleep(0.2)


@app.get("/camera/live.mjpg")
async def live_camera():
    return StreamingResponse(live_camera_frames(),media_type="multipart/x-mixed-replace; boundary=frame",headers={"Cache-Control": "no-store"},)

@app.get("/camera/live.jpg")
def live_camera_frame():
    if not LIVE_FRAME_PATH.is_file():
        raise HTTPException(status_code=503, detail="Camera is starting")
    try:
        frame = LIVE_FRAME_PATH.read_bytes()
    except FileNotFoundError:
        raise HTTPException(status_code=503, detail="Camera is starting") from None
    return Response(content=frame,media_type="image/jpeg",headers={"Cache-Control": "no-store"},)

@app.get("/camera/recordings")
def recordings():
    return [
        {"name": file.name, "size": file.stat().st_size, "recorded_at": file.stem}
        for file in sorted(RECORDINGS_DIR.glob("*.mp4"), reverse=True)
        if not file.name.endswith(".partial.mp4")
    ]

@app.get("/camera/recordings/{name}")
def recording(name: str):
    file = RECORDINGS_DIR / Path(name).name
    if file.suffix != ".mp4" or file.name.endswith(".partial.mp4") or not file.is_file():
        raise HTTPException(status_code=404, detail="Recording not found")
    return FileResponse(file, media_type="video/mp4", filename=file.name)

@app.get("/rfid/cards", response_model=list[Card])
def cards(member_id: str | None = Query(default=None, max_length=100)):
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
def create_automation(rule: AutomationRule):
    try:
        return save_automation(rule.model_dump())
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

@app.put("/automations/{rule_id}", response_model=AutomationRule)
def update_automation(rule_id: int, rule: AutomationRule):
    try:
        result = save_automation(rule.model_dump(), rule_id)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    if result is None: raise HTTPException(status_code=404, detail="找不到自動化規則")
    return result

@app.delete("/automations/{rule_id}", status_code=204)
def remove_automation(rule_id: int):
    if not delete_automation(rule_id): raise HTTPException(status_code=404, detail="找不到自動化規則")


@app.get("/scenes", response_model=list[Scene])
def scenes():
    return list_scenes()


@app.post("/scenes", response_model=Scene)
def create_scene(scene: Scene):
    try:
        return save_scene(scene.model_dump())
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

@app.put("/scenes/{scene_id}", response_model=Scene)
def update_scene(scene_id: int, scene: Scene):
    try:
        result = save_scene(scene.model_dump(), scene_id)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    if result is None:
        raise HTTPException(status_code=404, detail="找不到情境")
    return result


@app.delete("/scenes/{scene_id}", status_code=204)
def remove_scene(scene_id: int):
    if not delete_scene(scene_id):
        raise HTTPException(status_code=404, detail="找不到情境")
