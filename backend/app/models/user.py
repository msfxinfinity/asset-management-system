from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String

from app.db import Base
from app.utils.time import utcnow


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id"), nullable=False, index=True)
    role_type_id = Column(Integer, ForeignKey("role_types.id"), nullable=False, index=True)
    full_name = Column(String, nullable=False)
    username = Column(String, nullable=False, unique=True, index=True)
    email = Column(String, nullable=False, unique=True, index=True)
    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    is_superadmin = Column(Boolean, nullable=False, default=False)
    failed_login_attempts = Column(Integer, nullable=False, default=0)
    profile_picture = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
