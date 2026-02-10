from pydantic import BaseModel
from typing import Optional, Dict
from datetime import datetime

class AssetCreate(BaseModel):
    asset_name:str
    dept: Optional[str] = None
    assigned_to: Optional[str] = None
    geolocation: Optional[str] = None
    valid_till: Optional[datetime] = None

class AssetResponse(BaseModel):
    id: int
    asset_token: str
    status: str
    tenant_id: int
    created_at: datetime
    
    class Config:
        orm_mode = True

