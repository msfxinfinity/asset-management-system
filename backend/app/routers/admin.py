import uuid
import csv
import io
import logging
from datetime import datetime
from typing import Optional, List

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status, BackgroundTasks, Request
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from app.db import get_db
from app.deps import CurrentUser, require_permission
from app.models.asset import Asset
from app.models.asset_event import AssetEvent, AssetEventType
from app.models.department import Department, DepartmentFieldDefinition
from app.models.role_type import RoleType
from app.models.user import User
from app.models.tenant import Tenant
import app.schemas.admin as admin_schemas
from app.utils.security import hash_password
from app.services.email import send_email, get_welcome_email_html, SmtpConfig

router = APIRouter(prefix="/admin", tags=["Admin"])
DEFAULT_DEPARTMENT_CODE = "GEN"

logger = logging.getLogger(__name__)

# --- INTERNAL HELPER FUNCTIONS ---

def _tenant_role_or_404(db: Session, tenant_id: int, role_type_id: int) -> RoleType:
    """Ensures a role exists and belongs to the active tenant."""
    role = db.query(RoleType).filter(RoleType.id == role_type_id, RoleType.tenant_id == tenant_id).first()
    if not role: raise HTTPException(status_code=404, detail="Role not found")
    return role

def _tenant_department_or_404(db: Session, tenant_id: int, department_id: int) -> Department:
    """Ensures a department exists and belongs to the active tenant."""
    department = db.query(Department).filter(Department.id == department_id, Department.tenant_id == tenant_id).first()
    if not department: raise HTTPException(status_code=404, detail="Department not found")
    return department

def _default_department(db: Session, tenant_id: int) -> Department | None:
    """Retrieves the organizational default department."""
    return db.query(Department).filter(Department.tenant_id == tenant_id, Department.code == DEFAULT_DEPARTMENT_CODE).first()

def _get_tenant_smtp_config(tenant: Tenant) -> SmtpConfig:
    """Constructs an SMTP configuration object from tenant database records."""
    return SmtpConfig(
        host=tenant.smtp_host or "",
        port=tenant.smtp_port or 0,
        user=tenant.smtp_user or "",
        password=tenant.smtp_pass or "",
        from_address=tenant.smtp_from_address or "",
        from_name=tenant.smtp_from_name or "",
        encryption=tenant.smtp_encryption or "ssl",
    )

class TenantConfigUpdate(BaseModel):
    """Schema for updating tenant-wide system and mail configurations."""
    smtp_host: Optional[str] = None
    smtp_port: Optional[int] = None
    smtp_user: Optional[str] = None
    smtp_pass: Optional[str] = None
    smtp_from_address: Optional[str] = None
    smtp_from_name: Optional[str] = None
    smtp_encryption: Optional[str] = None
    imap_host: Optional[str] = None
    imap_port: Optional[int] = None
    imap_user: Optional[str] = None
    imap_pass: Optional[str] = None
    imap_encryption: Optional[str] = None
    app_url: Optional[str] = None

# --- CONFIGURATION ENDPOINTS ---

@router.get("/tenant/config", summary="Fetch Organizational Settings")
def get_tenant_config(db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("is_admin"))):
    """Retrieves current SMTP, IMAP, and system URL settings for the organization."""
    tenant = db.query(Tenant).filter(Tenant.id == current_user.tenant_id).first()
    if not tenant: raise HTTPException(status_code=404, detail="Tenant not found")
    return {
        "name": tenant.name, "code": tenant.code,
        "smtp_host": tenant.smtp_host, "smtp_port": tenant.smtp_port, "smtp_user": tenant.smtp_user, "smtp_pass": tenant.smtp_pass,
        "smtp_from_address": tenant.smtp_from_address, "smtp_from_name": tenant.smtp_from_name, "smtp_encryption": tenant.smtp_encryption,
        "imap_host": tenant.imap_host, "imap_port": tenant.imap_port, "imap_user": tenant.imap_user, "imap_pass": tenant.imap_pass,
        "imap_encryption": tenant.imap_encryption, "app_url": tenant.app_url or "http://localhost:8080",
    }

@router.patch("/tenant/config", summary="Update Organizational Settings")
def update_tenant_config(payload: TenantConfigUpdate, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("is_admin"))):
    """Updates organizational settings. Changes take effect immediately for all tenant users."""
    tenant = db.query(Tenant).filter(Tenant.id == current_user.tenant_id).first()
    if not tenant: raise HTTPException(status_code=404, detail="Tenant not found")
    # SMTP
    if payload.smtp_host is not None: tenant.smtp_host = payload.smtp_host.strip()
    if payload.smtp_port is not None: tenant.smtp_port = payload.smtp_port
    if payload.smtp_user is not None: tenant.smtp_user = payload.smtp_user.strip()
    if payload.smtp_pass is not None: tenant.smtp_pass = payload.smtp_pass.strip()
    if payload.smtp_from_address is not None: tenant.smtp_from_address = payload.smtp_from_address.strip()
    if payload.smtp_from_name is not None: tenant.smtp_from_name = payload.smtp_from_name.strip()
    if payload.smtp_encryption is not None: tenant.smtp_encryption = payload.smtp_encryption.strip()
    # IMAP
    if payload.imap_host is not None: tenant.imap_host = payload.imap_host.strip()
    if payload.imap_port is not None: tenant.imap_port = payload.imap_port
    if payload.imap_user is not None: tenant.imap_user = payload.imap_user.strip()
    if payload.imap_pass is not None: tenant.imap_pass = payload.imap_pass.strip()
    if payload.imap_encryption is not None: tenant.imap_encryption = payload.imap_encryption.strip()
    # General
    if payload.app_url is not None: tenant.app_url = payload.app_url.strip()
    db.commit()
    return get_tenant_config(db, current_user)

# --- USER & ROLE MANAGEMENT ---

@router.get("/roles", response_model=List[admin_schemas.RoleTypeResponse], summary="List Tenant Roles")
def get_roles(db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_roles"))):
    """Returns all RBAC roles defined for this organization."""
    return db.query(RoleType).filter(RoleType.tenant_id == current_user.tenant_id).order_by(RoleType.created_at.asc()).all()

@router.post("/roles", response_model=admin_schemas.RoleTypeResponse, status_code=status.HTTP_201_CREATED, summary="Create Custom Role")
def create_role(payload: admin_schemas.RoleTypeCreate, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_roles"))):
    """Defines a new organizational role with specific functional permissions."""
    existing = db.query(RoleType).filter(RoleType.tenant_id == current_user.tenant_id, RoleType.name == payload.name.strip()).first()
    if existing: raise HTTPException(status_code=409, detail="Role already exists")
    role = RoleType(tenant_id=current_user.tenant_id, name=payload.name.strip(), permissions={**admin_schemas.DEFAULT_PERMISSIONS, **(payload.permissions or {})}, is_system=False)
    db.add(role)
    db.commit()
    db.refresh(role)
    return role

@router.patch("/roles/{role_id}", response_model=admin_schemas.RoleTypeResponse, summary="Modify Role Permissions")
def update_role(role_id: int, payload: admin_schemas.RoleTypeUpdate, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_roles"))):
    """Updates the name or permission matrix of an existing organizational role."""
    role = _tenant_role_or_404(db, current_user.tenant_id, role_id)
    if payload.name is not None and payload.name.strip(): role.name = payload.name.strip()
    if payload.permissions is not None: role.permissions = {**admin_schemas.DEFAULT_PERMISSIONS, **payload.permissions}
    db.commit()
    db.refresh(role)
    return role

@router.delete("/roles/{role_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Remove Role")
def delete_role(role_id: int, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_roles"))):
    """Deletes a custom role. Built-in system roles and roles assigned to active users cannot be deleted."""
    role = _tenant_role_or_404(db, current_user.tenant_id, role_id)
    if role.is_system: raise HTTPException(status_code=400, detail="System role cannot be deleted")
    if db.query(User).filter(User.tenant_id == current_user.tenant_id, User.role_type_id == role.id).count():
        raise HTTPException(status_code=409, detail="Role is currently assigned to users")
    db.delete(role)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.get("/users", response_model=List[admin_schemas.UserResponse], summary="List Organization Users")
def get_users(db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_users"))):
    """Retrieves all user accounts belonging to this organization."""
    users = db.query(User).filter(User.tenant_id == current_user.tenant_id).order_by(User.created_at.asc()).all()
    primary_id = db.query(func.min(User.id)).filter(User.tenant_id == current_user.tenant_id).scalar()
    for u in users: u.is_primary = (u.id == primary_id)
    return users

@router.post("/users", response_model=admin_schemas.UserResponse, status_code=status.HTTP_201_CREATED, summary="Provision New User")
def create_user(payload: admin_schemas.UserCreate, background_tasks: BackgroundTasks, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_users"))):
    """Creates a new user and asynchronously dispatches a welcome email with credentials."""
    _tenant_role_or_404(db, current_user.tenant_id, payload.role_type_id)
    if db.query(User).filter(or_(User.username == payload.username.strip().lower(), User.email == payload.email.strip().lower())).first():
        raise HTTPException(status_code=409, detail="User already exists")
    user = User(tenant_id=current_user.tenant_id, role_type_id=payload.role_type_id, full_name=payload.full_name.strip(), username=payload.username.strip().lower(), email=payload.email.lower(), password_hash=hash_password(payload.password), is_active=payload.is_active)
    db.add(user)
    db.commit()
    db.refresh(user)
    # Async Welcome Email
    tenant = db.query(Tenant).filter(Tenant.id == user.tenant_id).first()
    if tenant and tenant.smtp_host:
        smtp_config = _get_tenant_smtp_config(tenant)
        welcome_html = get_welcome_email_html(user.full_name, user.username, payload.password, tenant.app_url or "http://localhost:8080")
        def safe_send():
            try: send_email("Welcome to GoAgile AMS", [user.email], welcome_html, smtp_config)
            except Exception as e: logger.error(f"Welcome email dispatch failed for {user.email}: {e}")
        background_tasks.add_task(safe_send)
    return user

@router.patch("/users/{user_id}", response_model=admin_schemas.UserResponse, summary="Modify User Account")
def update_user(user_id: int, payload: admin_schemas.UserUpdate, background_tasks: BackgroundTasks, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_users"))):
    """Updates user profile details or role assignments."""
    user = db.query(User).filter(User.id == user_id, User.tenant_id == current_user.tenant_id).first()
    if not user: raise HTTPException(status_code=404, detail="User not found")
    if payload.role_type_id is not None:
        _tenant_role_or_404(db, current_user.tenant_id, payload.role_type_id)
        user.role_type_id = payload.role_type_id
    if payload.full_name is not None: user.full_name = payload.full_name.strip()
    if payload.email is not None and payload.email.lower() != user.email:
        if db.query(User).filter(User.email == payload.email.lower(), User.id != user.id).first():
            raise HTTPException(status_code=409, detail="Email already taken")
        user.email = payload.email.lower()
    if payload.is_active is not None: user.is_active = payload.is_active
    db.commit()
    db.refresh(user)
    return user

@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Revoke User Access")
def delete_user(user_id: int, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_users"))):
    """Permanently deletes a user account. Users cannot delete their own active sessions."""
    user = db.query(User).filter(User.id == user_id, User.tenant_id == current_user.tenant_id).first()
    if not user or user.id == current_user.id: raise HTTPException(status_code=400, detail="Action not permitted")
    db.delete(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

# --- TEMPLATE & DEPARTMENT MANAGEMENT ---

@router.get("/departments", response_model=List[admin_schemas.DepartmentResponse], summary="List Organization Departments")
def get_departments(db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Returns all departments registered for this tenant."""
    return db.query(Department).filter(Department.tenant_id == current_user.tenant_id).order_by(Department.name.asc()).all()

@router.post("/departments", response_model=admin_schemas.DepartmentResponse, status_code=status.HTTP_201_CREATED, summary="Add New Department")
def create_department(payload: admin_schemas.DepartmentCreate, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Registers a new department with a unique organizational code."""
    if db.query(Department).filter(Department.tenant_id == current_user.tenant_id, Department.code == payload.code.strip().upper()).first():
        raise HTTPException(status_code=409, detail="Department code already exists")
    department = Department(tenant_id=current_user.tenant_id, name=payload.name.strip(), code=payload.code.strip().upper())
    db.add(department)
    db.commit()
    db.refresh(department)
    return department

class DepartmentUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None

@router.patch("/departments/{department_id}", response_model=admin_schemas.DepartmentResponse, summary="Modify Department Identity")
def update_department(department_id: int, payload: DepartmentUpdate, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Updates the display name or organizational code of a department."""
    department = _tenant_department_or_404(db, current_user.tenant_id, department_id)
    if payload.name is not None: department.name = payload.name.strip()
    if payload.code is not None: department.code = payload.code.strip().upper()
    db.commit()
    db.refresh(department)
    return department

@router.delete("/departments/{department_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Remove Department")
def delete_department(department_id: int, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Deletes a department. Prevents deletion if the department is linked to active asset records."""
    department = _tenant_department_or_404(db, current_user.tenant_id, department_id)
    if db.query(Asset).filter(Asset.department_id == department_id, Asset.is_deleted == False).count() > 0:
        raise HTTPException(status_code=409, detail="Cannot delete department with active assets")
    db.delete(department)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.get("/departments/{department_id}/fields", response_model=List[admin_schemas.DepartmentFieldDefinitionResponse], summary="Fetch Template Fields")
def get_department_fields(department_id: int, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Retrieves all custom and core field definitions for a specific department's template."""
    _tenant_department_or_404(db, current_user.tenant_id, department_id)
    return db.query(DepartmentFieldDefinition).filter(DepartmentFieldDefinition.department_id == department_id).order_by(DepartmentFieldDefinition.display_order.asc()).all()

@router.put("/departments/{department_id}/fields", response_model=List[admin_schemas.DepartmentFieldDefinitionResponse], summary="Override Template Schema")
def put_department_fields(department_id: int, payload: admin_schemas.DepartmentFieldsUpdateRequest, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Completely replaces the custom field template for a department. Used for re-ordering or batch updates."""
    _tenant_department_or_404(db, current_user.tenant_id, department_id)
    db.query(DepartmentFieldDefinition).filter(DepartmentFieldDefinition.department_id == department_id).delete()
    for item in payload.fields:
        db.add(DepartmentFieldDefinition(department_id=department_id, field_key=item.field_key, label=item.label, field_type=item.field_type, required=item.required, visible_when_blank=item.visible_when_blank, editable_by_roles=item.editable_by_roles, display_order=item.display_order))
    db.commit()
    return db.query(DepartmentFieldDefinition).filter(DepartmentFieldDefinition.department_id == department_id).order_by(DepartmentFieldDefinition.display_order.asc()).all()

@router.delete("/departments/{department_id}/fields/{field_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Remove Single Field from Template")
def delete_department_field(department_id: int, field_id: int, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("manage_templates"))):
    """Removes a specific field from a department's asset template."""
    _tenant_department_or_404(db, current_user.tenant_id, department_id)
    field = db.query(DepartmentFieldDefinition).filter(DepartmentFieldDefinition.id == field_id, DepartmentFieldDefinition.department_id == department_id).first()
    if not field: raise HTTPException(status_code=404, detail="Field not found")
    db.delete(field)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)

# --- DATA EXPORT & REPORTING ---

@router.get("/reports/assets/", summary="Export Inventory to CSV")
def export_assets_csv(request: Request, start_date: Optional[datetime] = None, end_date: Optional[datetime] = None, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("is_admin"))):
    """Generates a comprehensive CSV export of all organizational assets with secure image access tokens."""
    base_url = str(request.base_url).rstrip("/")
    query = db.query(Asset).filter(Asset.tenant_id == current_user.tenant_id)
    if start_date: query = query.filter(Asset.created_at >= start_date)
    if end_date: query = query.filter(Asset.created_at <= end_date)
    assets = query.all()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["ID", "Name", "Token", "City", "Building", "Floor", "Room", "Street", "Locality", "Postal Code", "Latitude", "Longitude", "Created At", "Image Link"])
    from app.services.jwt_tokens import issue_image_token
    for a in assets:
        img_token = issue_image_token(current_user.id, current_user.tenant_id, a.id)
        img_link = f"{base_url}/assets/{a.id}/image?image_token={img_token}" if a.image_url else "No Image"
        writer.writerow([a.id, a.asset_name, a.asset_token, a.city, a.building, a.floor, a.room, a.street, a.locality, a.postal_code, a.latitude, a.longitude, a.created_at, img_link])
    output.seek(0)
    return Response(content=output.getvalue(), media_type="text/csv", headers={"Content-Disposition": "attachment; filename=assets_report.csv"})

@router.get("/reports/logs/", summary="Export Audit Logs to CSV")
def export_logs_csv(start_date: Optional[datetime] = None, end_date: Optional[datetime] = None, db: Session = Depends(get_db), current_user: CurrentUser = Depends(require_permission("is_admin"))):
    """Generates a detailed audit log export capturing all user-driven asset events."""
    query = db.query(AssetEvent).filter(AssetEvent.tenant_id == current_user.tenant_id)
    if start_date: query = query.filter(AssetEvent.created_at >= start_date)
    if end_date: query = query.filter(AssetEvent.created_at <= end_date)
    logs = query.all()
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Event ID", "Asset ID", "Event Type", "User ID", "User Role", "Created At"])
    for l in logs: writer.writerow([l.id, l.asset_id, l.event_type, l.user_id, l.user_role, l.created_at])
    output.seek(0)
    return Response(content=output.getvalue(), media_type="text/csv", headers={"Content-Disposition": "attachment; filename=system_logs.csv"})
