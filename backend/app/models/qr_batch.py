from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base
from app.utils.time import utcnow


class QRBatch(Base):
    __tablename__ = "qr_batches"

    id = Column(Integer, primary_key=True, index=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id"), nullable=False, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True, index=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    quantity = Column(Integer, nullable=False)
    export_formats = Column(JSONB, nullable=False, default=list)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class QRBatchItem(Base):
    __tablename__ = "qr_batch_items"

    id = Column(Integer, primary_key=True, index=True)
    batch_id = Column(Integer, ForeignKey("qr_batches.id"), nullable=False, index=True)
    asset_id = Column(Integer, ForeignKey("assets.id"), nullable=False, index=True)
    serial_number = Column(String, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
