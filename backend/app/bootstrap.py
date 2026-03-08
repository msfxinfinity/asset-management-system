from sqlalchemy.orm import Session
import os

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
    superadmin_email = os.getenv("SUPERADMIN_EMAIL", "admin@goagile.com")
    superadmin_password = os.getenv("SUPERADMIN_PASSWORD", "goagile123")
    system_name = os.getenv("SYSTEM_NAME", "GoAgile")
    system_code = os.getenv("SYSTEM_CODE", "GOA")

    tenant = db.query(Tenant).filter(Tenant.code == system_code).first()

    if not tenant:
        tenant = Tenant(
            name=system_name, 
            code=system_code, 
            serial_counter=0, 
            initial_admin_password=superadmin_password,
            smtp_host=os.getenv("MAIL_HOST"),
            smtp_port=int(os.getenv("MAIL_PORT", "465")),
            smtp_user=os.getenv("MAIL_USERNAME"),
            smtp_pass=os.getenv("MAIL_PASSWORD"),
            smtp_from_address=os.getenv("MAIL_FROM_ADDRESS"),
            smtp_from_name=os.getenv("MAIL_FROM_NAME"),
            smtp_encryption=os.getenv("MAIL_ENCRYPTION", "ssl")
        )
        db.add(tenant)
        db.flush()
    elif tenant.initial_admin_password is None:
        tenant.initial_admin_password = superadmin_password
        # Also sync SMTP if empty
        if not tenant.smtp_host:
            tenant.smtp_host = os.getenv("MAIL_HOST")
            tenant.smtp_port = int(os.getenv("MAIL_PORT", "465"))
            tenant.smtp_user = os.getenv("MAIL_USERNAME")
            tenant.smtp_pass = os.getenv("MAIL_PASSWORD")
            tenant.smtp_from_address = os.getenv("MAIL_FROM_ADDRESS")
            tenant.smtp_from_name = os.getenv("MAIL_FROM_NAME")
            tenant.smtp_encryption = os.getenv("MAIL_ENCRYPTION", "ssl")
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

    admin_user = db.query(User).filter(User.username == superadmin_email).first()
    if not admin_user:
        db.add(
            User(
                tenant_id=tenant.id,
                role_type_id=admin_role.id,
                full_name=f"{system_name} Admin",
                username=superadmin_email,
                email=superadmin_email,
                password_hash=hash_password(superadmin_password),
                is_active=True,
                is_superadmin=True,
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
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=1,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="city",
                label="City",
                field_type="dropdown",
                required=True,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=2,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="building",
                label="Factory/Building",
                field_type="dropdown",
                required=True,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=3,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="floor",
                label="Floor",
                field_type="dropdown",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=4,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="room",
                label="Room/Zone",
                field_type="dropdown",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=5,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="project_name",
                label="Project",
                field_type="dropdown",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=6,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="asset_status",
                label="Asset Status",
                field_type="dropdown",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=7,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="asset_condition",
                label="Asset Condition",
                field_type="dropdown",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=8,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="street",
                label="Street",
                field_type="text",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=9,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="locality",
                label="Locality",
                field_type="text",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=10,
            ),
            DepartmentFieldDefinition(
                department_id=default_dept.id,
                field_key="postal_code",
                label="Postal Code",
                field_type="text",
                required=False,
                visible_when_blank=True,
                editable_by_roles=["Admin", "Worker"],
                display_order=11,
            ),
        ]
        db.add_all(base_fields)

    db.commit()
