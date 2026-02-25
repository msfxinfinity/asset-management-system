import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import CurrentUser, require_permission
from app.models.asset import Asset, AssetStatus
from app.models.asset_event import AssetEvent, AssetEventType
from app.models.department import Department, DepartmentFieldDefinition
from app.models.qr_batch import QRBatch, QRBatchItem
from app.models.role_type import RoleType
from app.models.user import User
from app.schemas.admin import (
    DEFAULT_PERMISSIONS,
    DepartmentCreate,
    DepartmentFieldDefinitionResponse,
    DepartmentFieldsUpdateRequest,
    DepartmentResponse,
    QRBatchCreateRequest,
    QRBatchResponse,
    RoleTypeCreate,
    RoleTypeResponse,
    RoleTypeUpdate,
    UserCreate,
    UserResetPasswordRequest,
    UserResponse,
    UserUpdate,
)
from app.services.qr_export import QRLabel, assert_export_formats, build_pdf, build_zip
from app.services.serials import next_serial_numbers
from app.utils.security import hash_password

router = APIRouter(prefix="/admin", tags=["Admin"])
DEFAULT_DEPARTMENT_CODE = "GEN"


def _tenant_role_or_404(db: Session, tenant_id: int, role_type_id: int) -> RoleType:
    role = (
        db.query(RoleType)
        .filter(RoleType.id == role_type_id, RoleType.tenant_id == tenant_id)
        .first()
    )
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    return role


def _tenant_department_or_404(db: Session, tenant_id: int, department_id: int) -> Department:
    department = (
        db.query(Department)
        .filter(Department.id == department_id, Department.tenant_id == tenant_id)
        .first()
    )
    if not department:
        raise HTTPException(status_code=404, detail="Department not found")
    return department


def _default_department(db: Session, tenant_id: int) -> Department | None:
    return (
        db.query(Department)
        .filter(Department.tenant_id == tenant_id, Department.code == DEFAULT_DEPARTMENT_CODE)
        .first()
    )


@router.get("/roles", response_model=list[RoleTypeResponse])
def get_roles(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_roles")),
):
    return (
        db.query(RoleType)
        .filter(RoleType.tenant_id == current_user.tenant_id)
        .order_by(RoleType.created_at.asc())
        .all()
    )


@router.post("/roles", response_model=RoleTypeResponse, status_code=status.HTTP_201_CREATED)
def create_role(
    payload: RoleTypeCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_roles")),
):
    existing = (
        db.query(RoleType)
        .filter(
            RoleType.tenant_id == current_user.tenant_id,
            RoleType.name == payload.name.strip(),
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Role already exists")

    role = RoleType(
        tenant_id=current_user.tenant_id,
        name=payload.name.strip(),
        permissions={**DEFAULT_PERMISSIONS, **(payload.permissions or {})},
        is_system=False,
    )
    db.add(role)
    db.commit()
    db.refresh(role)
    return role


@router.patch("/roles/{role_id}", response_model=RoleTypeResponse)
def update_role(
    role_id: int,
    payload: RoleTypeUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_roles")),
):
    role = _tenant_role_or_404(db, current_user.tenant_id, role_id)

    if payload.name is not None and payload.name.strip():
        role.name = payload.name.strip()
    if payload.permissions is not None:
        role.permissions = {**DEFAULT_PERMISSIONS, **payload.permissions}

    db.commit()
    db.refresh(role)
    return role


@router.delete("/roles/{role_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_role(
    role_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_roles")),
):
    role = _tenant_role_or_404(db, current_user.tenant_id, role_id)
    if role.is_system:
        raise HTTPException(status_code=400, detail="System role cannot be deleted")

    has_users = (
        db.query(User)
        .filter(User.tenant_id == current_user.tenant_id, User.role_type_id == role.id)
        .count()
    )
    if has_users:
        raise HTTPException(status_code=409, detail="Role is assigned to users")

    db.delete(role)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/users", response_model=list[UserResponse])
def get_users(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_users")),
):
    return (
        db.query(User)
        .filter(User.tenant_id == current_user.tenant_id)
        .order_by(User.created_at.asc())
        .all()
    )


@router.post("/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_users")),
):
    _tenant_role_or_404(db, current_user.tenant_id, payload.role_type_id)

    existing = db.query(User).filter(User.username == payload.username.strip().lower()).first()
    if existing:
        raise HTTPException(status_code=409, detail="Username already exists")

    user = User(
        tenant_id=current_user.tenant_id,
        role_type_id=payload.role_type_id,
        full_name=payload.full_name.strip(),
        username=payload.username.strip().lower(),
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        is_active=payload.is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.patch("/users/{user_id}", response_model=UserResponse)
def update_user(
    user_id: int,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_users")),
):
    user = (
        db.query(User)
        .filter(User.id == user_id, User.tenant_id == current_user.tenant_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if payload.role_type_id is not None:
        _tenant_role_or_404(db, current_user.tenant_id, payload.role_type_id)
        user.role_type_id = payload.role_type_id
    if payload.full_name is not None:
        user.full_name = payload.full_name.strip()
    if payload.email is not None:
        user.email = payload.email.lower()
    if payload.is_active is not None:
        user.is_active = payload.is_active

    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_users")),
):
    user = (
        db.query(User)
        .filter(User.id == user_id, User.tenant_id == current_user.tenant_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")

    has_batches = (
        db.query(QRBatch)
        .filter(
            QRBatch.tenant_id == current_user.tenant_id,
            QRBatch.created_by_user_id == user.id,
        )
        .count()
    )
    if has_batches:
        raise HTTPException(status_code=409, detail="User has QR batches")

    db.delete(user)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/users/{user_id}/reset-password", status_code=status.HTTP_204_NO_CONTENT)
def reset_password(
    user_id: int,
    payload: UserResetPasswordRequest,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_users")),
):
    user = (
        db.query(User)
        .filter(User.id == user_id, User.tenant_id == current_user.tenant_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.password_hash = hash_password(payload.password)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/departments", response_model=list[DepartmentResponse])
def get_departments(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_templates")),
):
    return (
        db.query(Department)
        .filter(Department.tenant_id == current_user.tenant_id)
        .order_by(Department.name.asc())
        .all()
    )


@router.post("/departments", response_model=DepartmentResponse, status_code=status.HTTP_201_CREATED)
def create_department(
    payload: DepartmentCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_templates")),
):
    existing = (
        db.query(Department)
        .filter(
            Department.tenant_id == current_user.tenant_id,
            Department.code == payload.code.strip().upper(),
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Department code already exists")

    department = Department(
        tenant_id=current_user.tenant_id,
        name=payload.name.strip(),
        code=payload.code.strip().upper(),
    )
    db.add(department)
    db.commit()
    db.refresh(department)
    return department


@router.get(
    "/departments/{department_id}/fields",
    response_model=list[DepartmentFieldDefinitionResponse],
)
def get_department_fields(
    department_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_templates")),
):
    _tenant_department_or_404(db, current_user.tenant_id, department_id)
    return (
        db.query(DepartmentFieldDefinition)
        .filter(DepartmentFieldDefinition.department_id == department_id)
        .order_by(DepartmentFieldDefinition.display_order.asc())
        .all()
    )


@router.put(
    "/departments/{department_id}/fields",
    response_model=list[DepartmentFieldDefinitionResponse],
)
def put_department_fields(
    department_id: int,
    payload: DepartmentFieldsUpdateRequest,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("manage_templates")),
):
    _tenant_department_or_404(db, current_user.tenant_id, department_id)
    (
        db.query(DepartmentFieldDefinition)
        .filter(DepartmentFieldDefinition.department_id == department_id)
        .delete()
    )
    for item in payload.fields:
        db.add(
            DepartmentFieldDefinition(
                department_id=department_id,
                field_key=item.field_key,
                label=item.label,
                field_type=item.field_type,
                required=item.required,
                visible_when_blank=item.visible_when_blank,
                editable_by_roles=item.editable_by_roles,
                display_order=item.display_order,
            )
        )
    db.commit()
    return (
        db.query(DepartmentFieldDefinition)
        .filter(DepartmentFieldDefinition.department_id == department_id)
        .order_by(DepartmentFieldDefinition.display_order.asc())
        .all()
    )


@router.post("/qr-batches", response_model=QRBatchResponse, status_code=status.HTTP_201_CREATED)
def create_qr_batch(
    payload: QRBatchCreateRequest,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("generate_qr")),
):
    quantity = payload.quantity
    if quantity < 1 or quantity > 500:
        raise HTTPException(status_code=400, detail="Quantity must be between 1 and 500")

    export_formats = assert_export_formats(payload.export_formats)
    department_id = payload.department_id
    if department_id is not None:
        _tenant_department_or_404(db, current_user.tenant_id, department_id)
    else:
        default_department = _default_department(db, current_user.tenant_id)
        if default_department:
            department_id = default_department.id

    serial_numbers = next_serial_numbers(db, current_user.tenant_id, quantity)
    batch = QRBatch(
        tenant_id=current_user.tenant_id,
        department_id=department_id,
        created_by_user_id=current_user.id,
        quantity=quantity,
        export_formats=export_formats,
    )
    db.add(batch)
    db.flush()

    asset_ids: list[int] = []
    for serial_number in serial_numbers:
        token = uuid.uuid4().hex
        asset = Asset(
            asset_token=token,
            serial_number=serial_number,
            tenant_id=current_user.tenant_id,
            department_id=department_id,
            status=AssetStatus.UNASSIGNED,
            attributes={},
        )
        db.add(asset)
        db.flush()
        asset_ids.append(asset.id)

        db.add(
            AssetEvent(
                asset_id=asset.id,
                tenant_id=current_user.tenant_id,
                event_type=AssetEventType.GENERATED,
                user_id=current_user.id,
                user_role=current_user.role_name,
                geolocation=None,
            )
        )
        db.add(
            QRBatchItem(
                batch_id=batch.id,
                asset_id=asset.id,
                serial_number=serial_number,
            )
        )

    db.commit()
    db.refresh(batch)
    return QRBatchResponse(
        id=batch.id,
        tenant_id=batch.tenant_id,
        department_id=batch.department_id,
        created_by_user_id=batch.created_by_user_id,
        quantity=batch.quantity,
        export_formats=batch.export_formats,
        created_at=batch.created_at,
        asset_ids=asset_ids,
    )


@router.get("/qr-batches/{batch_id}", response_model=QRBatchResponse)
def get_qr_batch(
    batch_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("generate_qr")),
):
    batch = (
        db.query(QRBatch)
        .filter(QRBatch.id == batch_id, QRBatch.tenant_id == current_user.tenant_id)
        .first()
    )
    if not batch:
        raise HTTPException(status_code=404, detail="QR batch not found")

    items = (
        db.query(QRBatchItem)
        .filter(QRBatchItem.batch_id == batch.id)
        .order_by(QRBatchItem.id.asc())
        .all()
    )
    return QRBatchResponse(
        id=batch.id,
        tenant_id=batch.tenant_id,
        department_id=batch.department_id,
        created_by_user_id=batch.created_by_user_id,
        quantity=batch.quantity,
        export_formats=batch.export_formats,
        created_at=batch.created_at,
        asset_ids=[item.asset_id for item in items],
    )


@router.get("/qr-batches/{batch_id}/download")
def download_qr_batch(
    batch_id: int,
    format: str = Query(..., pattern="^(pdf|zip)$"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_permission("generate_qr")),
):
    batch = (
        db.query(QRBatch)
        .filter(QRBatch.id == batch_id, QRBatch.tenant_id == current_user.tenant_id)
        .first()
    )
    if not batch:
        raise HTTPException(status_code=404, detail="QR batch not found")

    items = (
        db.query(QRBatchItem, Asset)
        .join(Asset, Asset.id == QRBatchItem.asset_id)
        .filter(QRBatchItem.batch_id == batch.id)
        .order_by(QRBatchItem.id.asc())
        .all()
    )
    labels = [
        QRLabel(serial_number=asset.serial_number, asset_token=asset.asset_token)
        for _, asset in items
    ]

    if format == "pdf":
        content = build_pdf(labels)
        filename = f"qr-batch-{batch_id}.pdf"
        media_type = "application/pdf"
    else:
        content = build_zip(labels)
        filename = f"qr-batch-{batch_id}.zip"
        media_type = "application/zip"

    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Content-Length": str(len(content)),
        },
    )
