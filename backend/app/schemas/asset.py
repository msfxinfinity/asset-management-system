from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class AssetCreate(BaseModel):
    department_id: Optional[int] = None
    asset_name: Optional[str] = None
    assigned_to: Optional[str] = None
    location_text: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    valid_till: Optional[datetime] = None
    attributes: dict = Field(default_factory=dict)


class AssetUpdate(BaseModel):
    asset_name: Optional[str] = None
    assigned_to: Optional[str] = None
    location_text: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    valid_till: Optional[datetime] = None
    attributes: dict = Field(default_factory=dict)


class AssetResponse(BaseModel):
    id: int
    asset_token: str
    serial_number: str
    tenant_id: int
    department_id: Optional[int] = None
    status: str
    asset_name: Optional[str] = None
    assigned_to: Optional[str] = None
    location_text: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    valid_till: Optional[datetime] = None
    attributes: dict = Field(default_factory=dict)
    maps_url: Optional[str] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AssetEventResponse(BaseModel):
    id: int
    asset_id: int
    event_type: str
    user_id: int
    user_role: str
    geolocation: Optional[dict] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AssetStatsResponse(BaseModel):
    total_assets: int
    active_assets: int
    archived_assets: int
    unassigned_assets: int


class AssetActivationResponse(BaseModel):
    message: str
    asset: AssetResponse
