from urllib.parse import quote_plus

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String, Index, Boolean
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base
from app.utils.time import utcnow

class AssetStatus:
    UNASSIGNED = "UNASSIGNED"
    ACTIVE = "ACTIVE"
    MAINTENANCE = "MAINTENANCE"
    RETIRED = "RETIRED"

class Asset(Base):
    __tablename__ = "assets"

    id = Column(Integer, primary_key=True, index=True)
    asset_token = Column(String, unique=True, nullable=False, index=True)
    serial_number = Column(String, nullable=True, index=True) # Now nullable as we might use token
    tenant_id = Column(Integer, ForeignKey("tenants.id"), nullable=False, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True, index=True)
    
    # We still keep attributes for Admin-customized fields
    attributes = Column(JSONB, nullable=False, default=dict)
    created_at = Column(DateTime, default=utcnow)

    __table_args__ = (
        Index("ix_asset_attributes_gin", "attributes", postgresql_using="gin"),
    )

    asset_name = Column(String, nullable=True)
    
    # Location fields (Dropdowns in UI)
    city = Column(String, nullable=True, index=True)
    building = Column(String, nullable=True)
    floor = Column(String, nullable=True)
    room = Column(String, nullable=True)
    
    # Expanded Location details
    street = Column(String, nullable=True)
    locality = Column(String, nullable=True)
    postal_code = Column(String, nullable=True)
    
    # Coordinates
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    
    # Image
    image_url = Column(String, nullable=True)
    
    valid_till = Column(DateTime, nullable=True)
    is_deleted = Column(Boolean, nullable=False, default=False, index=True)

    @property
    def maps_url(self) -> str | None:
        if self.latitude is not None and self.longitude is not None:
            return (
                "https://www.google.com/maps/search/?api=1&query="
                f"{self.latitude},{self.longitude}"
            )
        if self.city or self.building:
            query = ", ".join(filter(None, [self.room, self.floor, self.building, self.city]))
            return (
                "https://www.google.com/maps/search/?api=1&query="
                f"{quote_plus(query)}"
            )
        return None
