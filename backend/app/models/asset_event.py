import enum

from sqlalchemy import Column, DateTime, Enum, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base
from app.utils.time import utcnow


class AssetEventType(enum.Enum):
    CREATED = "CREATED"
    UPDATED = "UPDATED"
    ACTIVATED = "ACTIVATED"
    ARCHIVED = "ARCHIVED"
    GENERATED = "GENERATED"
    DELETED = "DELETED"


class AssetEvent(Base):
    __tablename__ = "asset_events"

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
        index=True
    )

    event_type = Column(
        Enum(AssetEventType),
        nullable=False
    )

    user_id = Column(Integer, nullable=False)
    user_role = Column(String, nullable=False)

    geolocation = Column(JSONB, nullable=True)

    created_at = Column(DateTime, default=utcnow, nullable=False)
