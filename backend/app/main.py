import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.bootstrap import seed_mvp_data
from app.db import Base, Sessionlocal, engine
from app.models import (  # noqa: F401
    asset,
    asset_event,
    department,
    qr_batch,
    role_type,
    tenant,
    user,
)
from app.routers import admin, assets, auth


@asynccontextmanager
async def lifespan(app: FastAPI):
    # During testing, we let the test suite handle DB setup
    if os.getenv("TESTING", "").lower() not in {"1", "true", "yes"}:
        Base.metadata.create_all(bind=engine)
        db = Sessionlocal()
        try:
            seed_mvp_data(db)
        finally:
            db.close()
    yield


app = FastAPI(title="GoAgile AMS API", version="1.0.0", lifespan=lifespan)

cors_origins_env = os.getenv("CORS_ALLOW_ORIGINS", "*")
allow_origins = [item.strip() for item in cors_origins_env.split(",") if item.strip()]
allow_credentials = allow_origins != ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins or ["*"],
    allow_credentials=allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(assets.router)


@app.get("/")
def health_check() -> dict:
    return {"status": "ok"}
