from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class AssetCreate(BaseModel):
    asset_token: str = Field(..., max_length=255)
    department_id: int
    asset_name: str = Field(..., max_length=255)
    city: str = Field(..., max_length=255)
    building: str = Field(..., max_length=255)
    floor: Optional[str] = Field(default=None, max_length=50)
    room: Optional[str] = Field(default=None, max_length=50)
    street: Optional[str] = Field(default=None, max_length=255)
    locality: Optional[str] = Field(default=None, max_length=255)
    postal_code: Optional[str] = Field(default=None, max_length=50)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    image_url: Optional[str] = Field(default=None, max_length=2048)
    valid_till: Optional[datetime] = None
    attributes: dict = Field(default_factory=dict)
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "asset_token": "QR-1234567890",
                "department_id": 2,
                "asset_name": "High-Pressure Valve",
                "city": "RIYADH",
                "building": "MAIN FACTORY",
                "floor": "1",
                "room": "Zone A",
                "street": "123 Industrial Rd",
                "locality": "Industrial Area",
                "postal_code": "11564",
                "latitude": 24.7136,
                "longitude": 46.6753,
                "attributes": {
                    "project_name": "Project Alpha",
                    "status": "Operational"
                }
            }
        }
    )


class AssetUpdate(BaseModel):
    department_id: Optional[int] = None
    asset_name: Optional[str] = Field(default=None, max_length=255)
    city: Optional[str] = Field(default=None, max_length=255)
    building: Optional[str] = Field(default=None, max_length=255)
    floor: Optional[str] = Field(default=None, max_length=50)
    room: Optional[str] = Field(default=None, max_length=50)
    street: Optional[str] = Field(default=None, max_length=255)
    locality: Optional[str] = Field(default=None, max_length=255)
    postal_code: Optional[str] = Field(default=None, max_length=50)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    image_url: Optional[str] = Field(default=None, max_length=2048)
    # 2MB max for base64 strings to prevent memory DoS
    image_base64: Optional[str] = Field(default=None, max_length=2097152) 
    valid_till: Optional[datetime] = None
    attributes: dict = Field(default_factory=dict)
    
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "asset_name": "Updated Valve Name",
                "city": "JEDDAH",
                "attributes": {
                    "status": "Under Maintenance"
                }
            }
        }
    )


class AssetResponse(BaseModel):
    id: int
    asset_token: str
    serial_number: Optional[str] = None
    tenant_id: int
    department_id: Optional[int] = None
    asset_name: Optional[str] = None
    city: Optional[str] = None
    building: Optional[str] = None
    floor: Optional[str] = None
    room: Optional[str] = None
    street: Optional[str] = None
    locality: Optional[str] = None
    postal_code: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    image_url: Optional[str] = None
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
    cities: list[str] = Field(default_factory=list)
    project_names: list[str] = Field(default_factory=list)


class AssetDropdownsResponse(BaseModel):
    cities: list[str]
    buildings: list[str]
    floors: list[str]
    rooms: list[str]
    asset_names: list[str]
    project_names: list[str] = Field(default_factory=list)
    statuses: list[str]
    conditions: list[str]
    custom_attributes: dict[str, list[str]] = Field(default_factory=dict)
