from sqlalchemy.orm import Session

from app.models.department import Department, DepartmentFieldDefinition
from app.models.role_type import RoleType
from app.models.tenant import Tenant
from app.models.user import User
from app.schemas.admin import DEFAULT_PERMISSIONS
from app.utils.security import hash_password


def _admin_permissions() -> dict:
    perms = dict(DEFAULT_PERMISSIONS)
    perms.update(
        {
            "is_admin": True,
            "manage_roles": True,
            "manage_users": True,
            "manage_templates": True,
            "generate_qr": True,
            "view_assets": True,
            "edit_assets": True,
            "scan_assets": True,
        }
    )
    return perms


def _worker_permissions() -> dict:
    perms = dict(DEFAULT_PERMISSIONS)
    perms.update(
        {
            "is_admin": False,
            "view_assets": True,
            "edit_assets": True,
            "scan_assets": True,
        }
    )
    return perms


def seed_mvp_data(db: Session) -> None:
    tenant = db.query(Tenant).filter(Tenant.id == 1).first()
    if not tenant:
        tenant = Tenant(id=1, name="GoAgile", code="GOA", serial_counter=0)
        db.add(tenant)
        db.flush()

    admin_role = (
        db.query(RoleType)
        .filter(RoleType.tenant_id == tenant.id, RoleType.name == "Admin")
        .first()
    )
    if not admin_role:
        admin_role = RoleType(
            tenant_id=tenant.id,
            name="Admin",
            permissions=_admin_permissions(),
            is_system=True,
        )
        db.add(admin_role)
        db.flush()

    worker_role = (
        db.query(RoleType)
        .filter(RoleType.tenant_id == tenant.id, RoleType.name == "Worker")
        .first()
    )
    if not worker_role:
        worker_role = RoleType(
            tenant_id=tenant.id,
            name="Worker",
            permissions=_worker_permissions(),
            is_system=True,
        )
        db.add(worker_role)
        db.flush()

    admin_user = db.query(User).filter(User.username == "admin@goagile.com").first()
    if not admin_user:
        db.add(
            User(
                tenant_id=tenant.id,
                role_type_id=admin_role.id,
                full_name="John Doe",
                username="admin@goagile.com",
                email="admin@goagile.com",
                password_hash=hash_password("goagile123"),
                is_active=True,
            )
        )

    default_dept = (
        db.query(Department)
        .filter(Department.tenant_id == tenant.id, Department.code == "GEN")
        .first()
    )
    if not default_dept:
        default_dept = Department(tenant_id=tenant.id, name="General", code="GEN")
        db.add(default_dept)
        db.flush()

    existing_fields = (
        db.query(DepartmentFieldDefinition)
        .filter(DepartmentFieldDefinition.department_id == default_dept.id)
        .count()
    )
    if existing_fields == 0:
        base_fields = [
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="asset_name",
                label="Asset Name",
                field_type="text",
                required=True,
                visible_when_blank=False,
                editable_by_roles=["Admin", "Worker"],
                display_order=1,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="assigned_to",
                label="Assigned To",
                field_type="text",
                required=False,
                visible_when_blank=False,
                editable_by_roles=["Admin", "Worker"],
                display_order=2,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="location_text",
                label="Location",
                field_type="text",
                required=False,
                visible_when_blank=False,
                editable_by_roles=["Admin", "Worker"],
                display_order=3,
            ),
        ]
        db.add_all(base_fields)

    db.commit()
