from app.db import base
from sqlalchemy import Column, Integer, DateTime, String, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import declarative_base
from datetime import datetime
import enum

class AssetStatus(enum.Enum):
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"
    
class Asset(Base):
    __tablename__ = 'assets'

    id = Column(Integer, primary_key=True, index=True)
    asset_token = Column(String, unique=True, nullable=False, index=True)
    tenant_id = Column(Integer, ForeignKey('tenants.id'), nullable=False)
    status = Column(Enum(AssetStatus), nullable=False, default=AssetStatus.ACTIVE)
    attributes = Column(JSONB, nullable=False, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)
