from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import uuid

from app.db import get_db
from app.models.asset import Asset
from app.models.asset_event import AssetEvent
from app.schemas.asset import AssetCreate, AssetResponse

router = APIRouter(prefix="/assets", tags=["Assets"])

@router.post("/", response_model=AssetResponse, status_code=status.HTTP_201_CREATED)
def create_asset(
    asset_in: AssetCreate,
    db: Session = Depends(get_db),
):
    tenant_id = 1
    user_id = 1
    user_role = "admin"

    asset_token = str(uuid.uuid4())
    asset_obj = Asset(
        asset_token=asset_token,
        tenant_id=tenant_id,
        status="ACTIVE", 
        **asset_in.dict()
    )

    db.add(asset_obj)
    db.flush()

    event=AssetEvent(
        asset_id=asset_obj.id,
        tenant_id=tenant_id,
        event_type="CREATED",
        user_id=user_id,
        user_role=user_role,
        geolocation=asset_obj.geolocation,
    )

    db.add(event)
    db.commit()
    db.refresh(asset_obj)

    return asset_obj