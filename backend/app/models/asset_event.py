from app.db import base
from sqlalchemy import Column,  Integer, String, DateTime, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.declarative import declarative_base
from datetime import datetime
import enum

class AssetEventType(enum.Enum):
    CREATED = "created"
    UPDATED = "updated"
    ARCHIVED = "archived"
    DELETED = "deleted"

class AssetEvent(Base):
    __table_name__ = "asset_events"

    id = Column(Integer, primary_key=True, autoincrement=True)

    asset_id = Column(
        Integer,
        ForeignKey("assets.id"),
        nullable=False,
        index=True
    )

    tenant_id = Column(
        Integer,
        ForeignKey("tenants.id"),
        nullable=False,
        Index=True
    )

    event_type = Column(
        Enum(AssetEventType),
        nullable=False
    )

    user_id = Column(Integer,nullable=False)
    user_role = Column(String, nullable=False)

    geolocation = Column(JSONB, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

