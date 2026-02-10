from fastapi import FastAPI
from app.db import engine, Base
from app.models import asset, asset_event, tenant
from app.routers import assets

app = FastAPI()
app.include_router(assets.router)

@app.on_event("startup")
def on_startup():
    Base.metadata.create_all(bind=engine)

@app.get("/")
def health_check():
    return {"status": "ok"}