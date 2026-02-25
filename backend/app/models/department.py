from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base
from app.utils.time import utcnow


class Department(Base):
    __tablename__ = "departments"

    id = Column(Integer, primary_key=True, index=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    code = Column(String, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class DepartmentFieldDefinition(Base):
    __tablename__ = "department_field_definitions"

    id = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=False, index=True)
    field_key = Column(String, nullable=False)
    label = Column(String, nullable=False)
    field_type = Column(String, nullable=False, default="text")
    required = Column(Boolean, nullable=False, default=False)
    visible_when_blank = Column(Boolean, nullable=False, default=False)
    editable_by_roles = Column(JSONB, nullable=False, default=list)
    display_order = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, default=utcnow, nullable=False)
