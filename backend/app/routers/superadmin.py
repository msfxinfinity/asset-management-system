from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from app.db import get_db
from app.deps import CurrentUser, get_current_user
from app.models.tenant import Tenant
from app.models.role_type import RoleType
from app.models.user import User
from app.models.asset import Asset
from app.models.asset_event import AssetEvent
from app.models.department import Department, DepartmentFieldDefinition
from app.utils.security import hash_password
from app.schemas.admin import DEFAULT_PERMISSIONS

router = APIRouter(prefix="/superadmin", tags=["SuperAdmin"])

# --- SCHEMAS ---

class TenantCreate(BaseModel):
    """Payload for registering a new organization."""
    name: str
    code: str
    admin_email: EmailStr
    admin_password: str

class TenantUpdate(BaseModel):
    """Payload for modifying organizational metadata."""
    name: Optional[str] = None

class TenantResponse(BaseModel):
    """Detailed representation of a tenant including administrative troubleshooting data."""
    id: int
    name: str
    code: str
    admin_email: Optional[str] = None
    admin_username: Optional[str] = None
    admin_password: Optional[str] = None
    
    class Config:
        from_attributes = True

# --- INTERNAL INITIALIZATION LOGIC ---

def _initialize_tenant(db: Session, tenant: Tenant, admin_email: str, admin_password: str):
    """
    Bootstrap a new organization with foundational security and data structures.
    This includes creating default RBAC roles, the primary admin account, and 
    the 'General' department template.
    """
    # 1. Create System Admin Role
    admin_perms = dict(DEFAULT_PERMISSIONS)
    admin_perms.update({
        "is_admin": True, "manage_roles": True, "manage_users": True,
        "manage_templates": True, "generate_qr": True, "view_assets": True,
        "edit_assets": True, "scan_assets": True,
    })
    admin_role = RoleType(
        tenant_id=tenant.id, name="Admin", permissions=admin_perms, is_system=True
    )
    db.add(admin_role)
    
    # 2. Create Standard Worker Role
    worker_perms = dict(DEFAULT_PERMISSIONS)
    worker_perms.update({"view_assets": True, "edit_assets": True, "scan_assets": True})
    worker_role = RoleType(
        tenant_id=tenant.id, name="Worker", permissions=worker_perms, is_system=True
    )
    db.add(worker_role)
    db.flush()

    # 3. Provision the Initial Organization Administrator
    db.add(User(
        tenant_id=tenant.id,
        role_type_id=admin_role.id,
        full_name=f"{tenant.name} Admin",
        username=admin_email.lower(),
        email=admin_email.lower(),
        password_hash=hash_password(admin_password),
        is_active=True,
    ))

    # 4. Initialize 'General' Asset Template
    dept = Department(tenant_id=tenant.id, name="General", code="GEN")
    db.add(dept)
    db.flush()

    # 5. Seed Core Field Definitions
    # These fields provide universal asset metadata across all organizations.
    base_fields = [
        ("asset_name", "Asset Name", "text", True, 1),
        ("city", "City", "dropdown", True, 2),
        ("building", "Factory/Building", "dropdown", True, 3),
        ("floor", "Floor", "dropdown", False, 4),
        ("room", "Room/Zone", "dropdown", False, 5),
        ("street", "Street", "text", False, 6),
        ("locality", "Locality", "text", False, 7),
        ("postal_code", "Postal Code", "text", False, 8),
        ("project_name", "Project", "dropdown", False, 9),
    ]
    for key, label, ftype, req, order in base_fields:
        db.add(DepartmentFieldDefinition(
            department_id=dept.id, field_key=key, label=label,
            field_type=ftype, required=req, visible_when_blank=True,
            editable_by_roles=["Admin", "Worker"], display_order=order
        ))

def require_superadmin(current_user: CurrentUser = Depends(get_current_user)):
    """Security guard ensuring only system-level administrators can access these endpoints."""
    if not current_user.is_superadmin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="System Administrator privileges required"
        )
    return current_user

# --- PLATFORM MANAGEMENT ENDPOINTS ---

@router.get("/tenants", response_model=List[TenantResponse], summary="List Platform Organizations")
def get_tenants(
    db: Session = Depends(get_db),
    _ : CurrentUser = Depends(require_superadmin)
):
    """
    Retrieves all tenant organizations on the platform.
    Includes primary admin credentials for troubleshooting and onboarding support.
    """
    tenants = db.query(Tenant).all()
    results = []
    for t in tenants:
        # Resolve the account owner for this tenant
        admin = (
            db.query(User)
            .filter(User.tenant_id == t.id)
            .order_by(User.id.asc())
            .first()
        )
        t_resp = TenantResponse.from_orm(t)
        if admin:
            t_resp.admin_email = admin.email
            t_resp.admin_username = admin.username
            t_resp.admin_password = t.initial_admin_password
        results.append(t_resp)
    return results

@router.post("/tenants", response_model=TenantResponse, status_code=status.HTTP_201_CREATED, summary="Provision New Organization")
def create_tenant(
    payload: TenantCreate,
    db: Session = Depends(get_db),
    _ : CurrentUser = Depends(require_superadmin)
):
    """
    Full-stack onboarding of a new organization.
    Creates the tenant record and automatically bootstraps roles, users, and templates.
    """
    existing = db.query(Tenant).filter(Tenant.code == payload.code.upper()).first()
    if existing:
        raise HTTPException(status_code=400, detail="Tenant code already exists")
    
    tenant = Tenant(
        name=payload.name,
        code=payload.code.upper(),
        initial_admin_password=payload.admin_password
    )
    db.add(tenant)
    db.flush()
    
    _initialize_tenant(db, tenant, payload.admin_email, payload.admin_password)
    
    db.commit()
    db.refresh(tenant)
    return tenant

@router.patch("/tenants/{tenant_id}", response_model=TenantResponse, summary="Rename Organization")
def update_tenant(
    tenant_id: int,
    payload: TenantUpdate,
    db: Session = Depends(get_db),
    _ : CurrentUser = Depends(require_superadmin)
):
    """Updates the legal name of a tenant organization."""
    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    
    if payload.name:
        tenant.name = payload.name.strip()
    
    db.commit()
    db.refresh(tenant)
    return tenant

@router.get("/logs/{log_type}", summary="Stream System Logs")
def get_logs(
    log_type: str,
    _ : CurrentUser = Depends(require_superadmin)
):
    """
    Diagnostic tool to view the most recent service logs directly from the platform UI.
    Supports 'backend' and 'frontend' logs.
    """
    import os
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    
    if log_type == "backend":
        log_file = os.path.join(root, "backend", "server.log")
    else:
        log_file = os.path.join(root, "frontend", "server.log")
        
    if not os.path.exists(log_file):
        return {"logs": f"Log file not available. CWD: {os.getcwd()}"}
    
    with open(log_file, "r") as f:
        # Optimized for quick inspection
        lines = f.readlines()
        return {"logs": "".join(lines[-500:])}

@router.get("/database/tables", summary="Inspect Physical Schema")
def list_tables(
    db: Session = Depends(get_db),
    _ : CurrentUser = Depends(require_superadmin)
):
    """Exposes all physical tables in the database for schema verification."""
    from sqlalchemy import inspect
    inspector = inspect(db.get_bind())
    tables = inspector.get_table_names()
    return {"tables": tables}

@router.get("/database/table/{table_name}", summary="Raw Data Inspection")
def get_table_data(
    table_name: str,
    db: Session = Depends(get_db),
    _ : CurrentUser = Depends(require_superadmin)
):
    """
    Fetches raw table data for low-level system troubleshooting.
    Limited to 100 rows per request for system performance safety.
    """
    from sqlalchemy import text
    try:
        from sqlalchemy import inspect
        inspector = inspect(db.get_bind())
        if table_name not in inspector.get_table_names():
            raise HTTPException(status_code=404, detail="Table not found")
            
        result = db.execute(text(f"SELECT * FROM {table_name} LIMIT 100"))
        cols = result.keys()
        data = [dict(zip(cols, row)) for row in result.fetchall()]
        # Serialize non-JSON objects
        for row in data:
            for k, v in row.items():
                if hasattr(v, "isoformat"):
                    row[k] = v.isoformat()
        return {"columns": list(cols), "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/tenants/{tenant_id}", summary="Purge Organization Data")
def delete_tenant(
    tenant_id: int,
    db: Session = Depends(get_db),
    _ : CurrentUser = Depends(require_superadmin)
):
    """
    Performs a cascading deletion of all tenant data.
    PROTECTION: The primary system tenant (ID: 1) is immutable.
    """
    if tenant_id == 1:
        raise HTTPException(status_code=400, detail="The primary organizational tenant cannot be deleted.")

    tenant = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    
    # 1. Cascade Assets & Lifecycle Events
    db.query(AssetEvent).filter(AssetEvent.tenant_id == tenant_id).delete(synchronize_session=False)
    db.query(Asset).filter(Asset.tenant_id == tenant_id).delete(synchronize_session=False)
    
    # 2. Cascade Department Templates
    dept_ids = [d.id for d in db.query(Department).filter(Department.tenant_id == tenant_id).all()]
    if dept_ids:
        db.query(DepartmentFieldDefinition).filter(DepartmentFieldDefinition.department_id.in_(dept_ids)).delete(synchronize_session=False)
        db.query(Department).filter(Department.tenant_id == tenant_id).delete(synchronize_session=False)

    # 3. Cascade Users & RBAC Rules
    db.query(User).filter(User.tenant_id == tenant_id).delete(synchronize_session=False)
    db.query(RoleType).filter(RoleType.tenant_id == tenant_id).delete(synchronize_session=False)

    # 4. Final Organizational Purge
    db.delete(tenant)
    db.commit()
    return {"status": "success", "message": "Organizational data has been fully purged."}
