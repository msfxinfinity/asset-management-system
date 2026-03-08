from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field

DEFAULT_PERMISSIONS = {
    "is_admin": False,
    "manage_roles": False,
    "manage_users": False,
    "manage_templates": False,
    "generate_qr": False,
    "view_assets": True,
    "edit_assets": False,
    "scan_assets": True,
}


class RoleTypeCreate(BaseModel):
    name: str
    permissions: dict = Field(default_factory=lambda: dict(DEFAULT_PERMISSIONS))

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Supervisor",
                "permissions": {
                    "view_assets": True,
                    "edit_assets": True
                }
            }
        }
    )


class RoleTypeUpdate(BaseModel):
    name: Optional[str] = None
    permissions: Optional[dict] = None


class RoleTypeResponse(BaseModel):
    id: int
    tenant_id: int
    name: str
    permissions: dict
    is_system: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserCreate(BaseModel):
    full_name: str
    username: str
    email: EmailStr
    password: str
    role_type_id: int
    is_active: bool = True

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "full_name": "Jane Smith",
                "username": "janesmith",
                "email": "jane@example.com",
                "password": "SecurePassword123!",
                "role_type_id": 2,
                "is_active": True
            }
        }
    )


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    role_type_id: Optional[int] = None
    is_active: Optional[bool] = None


class UserResetPasswordRequest(BaseModel):
    password: str


class UserResponse(BaseModel):
    id: int
    tenant_id: int
    role_type_id: int
    full_name: str
    username: str
    email: EmailStr
    is_active: bool
    is_superadmin: bool = False
    is_primary: bool = False
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DepartmentCreate(BaseModel):
    name: str
    code: str

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Mechanical Engineering",
                "code": "MECH"
            }
        }
    )


class DepartmentResponse(BaseModel):
    id: int
    tenant_id: int
    name: str
    code: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DepartmentFieldDefinitionInput(BaseModel):
    field_key: str
    label: str
    field_type: str = "text"
    required: bool = False
    visible_when_blank: bool = False
    editable_by_roles: List[str] = Field(default_factory=list)
    display_order: int = 0


class DepartmentFieldDefinitionResponse(BaseModel):
    id: int
    department_id: int
    field_key: str
    label: str
    field_type: str
    required: bool
    visible_when_blank: bool
    editable_by_roles: List[str]
    display_order: int
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DepartmentFieldsUpdateRequest(BaseModel):
    fields: List[DepartmentFieldDefinitionInput]
