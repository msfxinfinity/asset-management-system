import enum
from urllib.parse import quote_plus

from sqlalchemy import Column, DateTime, Enum, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base
from app.utils.time import utcnow

class AssetStatus(enum.Enum):
    UNASSIGNED = "UNASSIGNED"
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"


class Asset(Base):
    __tablename__ = "assets"

    id = Column(Integer, primary_key=True, index=True)
    asset_token = Column(String, unique=True, nullable=False, index=True)
    serial_number = Column(String, nullable=False, index=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id"), nullable=False, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True, index=True)
    status = Column(
        Enum(AssetStatus), nullable=False, default=AssetStatus.UNASSIGNED, index=True
    )
    attributes = Column(JSONB, nullable=False, default=dict)
    created_at = Column(DateTime, default=utcnow)

    asset_name = Column(String, nullable=True)
    assigned_to = Column(String, nullable=True)
    location_text = Column(String, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    valid_till = Column(DateTime, nullable=True)

    @property
    def maps_url(self) -> str | None:
        if self.latitude is not None and self.longitude is not None:
            return (
                "https://www.google.com/maps/search/?api=1&query="
                f"{self.latitude},{self.longitude}"
            )
        if self.location_text:
            return (
                "https://www.google.com/maps/search/?api=1&query="
                f"{quote_plus(self.location_text)}"
            )
        return None
