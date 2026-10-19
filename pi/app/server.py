from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from house_pi import get_card, list_access_logs, list_cards, list_dht11_readings

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

@app.get("/health")
def health():
    return {"status": "ok"}


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
