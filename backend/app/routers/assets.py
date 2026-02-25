import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import CurrentUser, get_current_user
from app.models.asset import Asset, AssetStatus
from app.models.asset_event import AssetEvent, AssetEventType
from app.models.department import Department, DepartmentFieldDefinition
from app.schemas.admin import DepartmentFieldDefinitionResponse
from app.schemas.asset import (
    AssetActivationResponse,
    AssetCreate,
    AssetEventResponse,
    AssetResponse,
    AssetStatsResponse,
    AssetUpdate,
)
from app.services.serials import next_serial_numbers

router = APIRouter(prefix="/assets", tags=["Assets"])
DEFAULT_DEPARTMENT_CODE = "GEN"

CORE_FIELD_MAP = {
    "asset_name": "asset_name",
    "assigned_to": "assigned_to",
    "location_text": "location_text",
    "valid_till": "valid_till",
    "latitude": "latitude",
    "longitude": "longitude",
}


def _get_asset_or_404(db: Session, tenant_id: int, asset_id: int) -> Asset:
    asset = (
        db.query(Asset)
        .filter(Asset.id == asset_id, Asset.tenant_id == tenant_id)
        .first()
    )
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


def _department_exists(db: Session, tenant_id: int, department_id: int) -> Department:
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


def _create_event(
    db: Session,
    *,
    asset: Asset,
    event_type: AssetEventType,
    current_user: CurrentUser,
) -> None:
    geo = None
    if asset.latitude is not None and asset.longitude is not None:
        geo = {"lat": asset.latitude, "lng": asset.longitude}
    elif asset.location_text:
        geo = {"location_text": asset.location_text}

    db.add(
        AssetEvent(
            asset_id=asset.id,
            tenant_id=current_user.tenant_id,
            event_type=event_type,
            user_id=current_user.id,
            user_role=current_user.role_name,
            geolocation=geo,
        )
    )


def _fetch_field_defs(db: Session, asset: Asset) -> list[DepartmentFieldDefinition]:
    if asset.department_id is None:
        return []
    return (
        db.query(DepartmentFieldDefinition)
        .filter(DepartmentFieldDefinition.department_id == asset.department_id)
        .all()
    )


def _required_missing(asset: Asset, field_defs: list[DepartmentFieldDefinition]) -> list[str]:
    attributes = asset.attributes or {}
    missing = []
    for definition in field_defs:
        if not definition.required:
            continue
        key = definition.field_key
        if key in CORE_FIELD_MAP:
            value = getattr(asset, CORE_FIELD_MAP[key], None)
        else:
            value = attributes.get(key)
        if value is None or value == "":
            missing.append(key)
    return missing


@router.post("/", response_model=AssetResponse, status_code=status.HTTP_201_CREATED)
def create_asset(
    payload: AssetCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    if not current_user.permissions.get("generate_qr"):
        raise HTTPException(status_code=403, detail="Only admin-level roles can create assets")

    department_id = payload.department_id
    if department_id is not None:
        _department_exists(db, current_user.tenant_id, department_id)
    else:
        default_department = _default_department(db, current_user.tenant_id)
        if default_department:
            department_id = default_department.id

    serial_number = next_serial_numbers(db, current_user.tenant_id, 1)[0]
    asset = Asset(
        asset_token=uuid.uuid4().hex,
        serial_number=serial_number,
        tenant_id=current_user.tenant_id,
        department_id=department_id,
        status=AssetStatus.UNASSIGNED,
        asset_name=payload.asset_name,
        assigned_to=payload.assigned_to,
        location_text=payload.location_text,
        latitude=payload.latitude,
        longitude=payload.longitude,
        valid_till=payload.valid_till,
        attributes=payload.attributes or {},
    )
    db.add(asset)
    db.flush()

    missing_required = _required_missing(asset, _fetch_field_defs(db, asset))
    if not missing_required:
        asset.status = AssetStatus.ACTIVE

    _create_event(
        db,
        asset=asset,
        event_type=AssetEventType.CREATED,
        current_user=current_user,
    )
    db.commit()
    db.refresh(asset)
    return asset


@router.get("/", response_model=list[AssetResponse])
def get_assets(
    q: Optional[str] = Query(default=None),
    status_filter: Optional[str] = Query(default=None, alias="status"),
    department_id: Optional[int] = Query(default=None),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    query = db.query(Asset).filter(Asset.tenant_id == current_user.tenant_id)

    if status_filter:
        normalized = status_filter.strip().upper()
        allowed = {item.value for item in AssetStatus}
        if normalized not in allowed:
            raise HTTPException(status_code=400, detail="Invalid status filter")
        query = query.filter(Asset.status == AssetStatus(normalized))

    if department_id is not None:
        query = query.filter(Asset.department_id == department_id)

    if q and q.strip():
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(
                Asset.asset_name.ilike(like),
                Asset.serial_number.ilike(like),
                Asset.asset_token.ilike(like),
                Asset.assigned_to.ilike(like),
                Asset.location_text.ilike(like),
            )
        )

    return query.order_by(Asset.created_at.desc()).all()


@router.get("/stats", response_model=AssetStatsResponse)
def get_asset_stats(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    base_query = db.query(Asset).filter(Asset.tenant_id == current_user.tenant_id)
    total_assets = base_query.count()
    active_assets = base_query.filter(Asset.status == AssetStatus.ACTIVE).count()
    archived_assets = base_query.filter(Asset.status == AssetStatus.ARCHIVED).count()
    unassigned_assets = base_query.filter(Asset.status == AssetStatus.UNASSIGNED).count()
    return AssetStatsResponse(
        total_assets=total_assets,
        active_assets=active_assets,
        archived_assets=archived_assets,
        unassigned_assets=unassigned_assets,
    )


@router.get("/by-qr/{token}", response_model=AssetResponse)
def get_asset_by_qr(
    token: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    asset = (
        db.query(Asset)
        .filter(Asset.asset_token == token, Asset.tenant_id == current_user.tenant_id)
        .first()
    )
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


@router.get("/by-token/{token}", response_model=AssetResponse)
def get_asset_by_token(
    token: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    return get_asset_by_qr(token=token, db=db, current_user=current_user)


@router.get("/{asset_id}", response_model=AssetResponse)
def get_asset(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    return _get_asset_or_404(db, current_user.tenant_id, asset_id)


@router.patch("/{asset_id}", response_model=AssetResponse)
def update_asset(
    asset_id: int,
    payload: AssetUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    if not current_user.permissions.get("edit_assets"):
        raise HTTPException(status_code=403, detail="Missing permission: edit_assets")

    asset = _get_asset_or_404(db, current_user.tenant_id, asset_id)
    if asset.status == AssetStatus.ARCHIVED:
        raise HTTPException(status_code=409, detail="Archived assets are read-only")

    field_defs = _fetch_field_defs(db, asset)
    editable_keys = {
        definition.field_key
        for definition in field_defs
        if current_user.role_name in (definition.editable_by_roles or [])
    }

    core_updates = {
        "asset_name": payload.asset_name,
        "assigned_to": payload.assigned_to,
        "location_text": payload.location_text,
        "valid_till": payload.valid_till,
        "latitude": payload.latitude,
        "longitude": payload.longitude,
    }

    for key, value in core_updates.items():
        if value is None:
            continue
        if not current_user.is_admin and field_defs and key not in editable_keys:
            raise HTTPException(status_code=403, detail=f"Field '{key}' is not editable")
        setattr(asset, key, value)

    new_attributes = payload.attributes or {}
    if new_attributes:
        if not current_user.is_admin and field_defs:
            forbidden = [k for k in new_attributes.keys() if k not in editable_keys]
            if forbidden:
                raise HTTPException(
                    status_code=403,
                    detail=f"Fields not editable for role: {', '.join(forbidden)}",
                )
        merged = dict(asset.attributes or {})
        merged.update(new_attributes)
        asset.attributes = merged

    _create_event(
        db,
        asset=asset,
        event_type=AssetEventType.UPDATED,
        current_user=current_user,
    )
    db.commit()
    db.refresh(asset)
    return asset


@router.post("/{asset_id}/activate", response_model=AssetActivationResponse)
def activate_asset(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    if not current_user.permissions.get("edit_assets"):
        raise HTTPException(status_code=403, detail="Missing permission: edit_assets")

    asset = _get_asset_or_404(db, current_user.tenant_id, asset_id)
    if asset.status == AssetStatus.ARCHIVED:
        raise HTTPException(status_code=409, detail="Archived assets cannot be activated")

    missing = _required_missing(asset, _fetch_field_defs(db, asset))
    if missing:
        raise HTTPException(
            status_code=409,
            detail=f"Missing required fields: {', '.join(missing)}",
        )

    asset.status = AssetStatus.ACTIVE
    _create_event(
        db,
        asset=asset,
        event_type=AssetEventType.ACTIVATED,
        current_user=current_user,
    )
    db.commit()
    db.refresh(asset)
    return AssetActivationResponse(message="Asset activated", asset=asset)


@router.patch("/{asset_id}/archive", response_model=AssetResponse)
def archive_asset(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    if not current_user.permissions.get("edit_assets"):
        raise HTTPException(status_code=403, detail="Missing permission: edit_assets")

    asset = _get_asset_or_404(db, current_user.tenant_id, asset_id)
    if asset.status == AssetStatus.ARCHIVED:
        raise HTTPException(status_code=409, detail="Asset already archived")
    asset.status = AssetStatus.ARCHIVED
    _create_event(
        db,
        asset=asset,
        event_type=AssetEventType.ARCHIVED,
        current_user=current_user,
    )
    db.commit()
    db.refresh(asset)
    return asset


@router.get("/{asset_id}/events", response_model=list[AssetEventResponse])
def get_asset_events(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    _get_asset_or_404(db, current_user.tenant_id, asset_id)
    return (
        db.query(AssetEvent)
        .filter(
            AssetEvent.asset_id == asset_id,
            AssetEvent.tenant_id == current_user.tenant_id,
        )
        .order_by(AssetEvent.created_at.desc())
        .all()
    )


@router.get(
    "/{asset_id}/fields",
    response_model=list[DepartmentFieldDefinitionResponse],
)
def get_asset_fields(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    asset = _get_asset_or_404(db, current_user.tenant_id, asset_id)
    if asset.department_id is None:
        return []
    return (
        db.query(DepartmentFieldDefinition)
        .filter(DepartmentFieldDefinition.department_id == asset.department_id)
        .order_by(DepartmentFieldDefinition.display_order.asc())
        .all()
    )
