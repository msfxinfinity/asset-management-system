import uuid
import base64
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import or_, distinct
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import CurrentUser, get_current_user
from app.models.asset import Asset
from app.models.asset_event import AssetEvent, AssetEventType
from app.models.department import Department, DepartmentFieldDefinition
from app.models.tenant import Tenant
from app.schemas.admin import DepartmentFieldDefinitionResponse
from app.schemas.asset import (
    AssetCreate,
    AssetEventResponse,
    AssetResponse,
    AssetStatsResponse,
    AssetUpdate,
    AssetDropdownsResponse,
)

router = APIRouter(prefix="/assets", tags=["Assets"])
DEFAULT_DEPARTMENT_CODE = "GEN"

# Mapping of frontend field names to database column names for dynamic attribute handling
CORE_FIELD_MAP = {
    "asset_name": "asset_name",
    "department_id": "department_id",
    "city": "city",
    "building": "building",
    "floor": "floor",
    "room": "room",
    "street": "street",
    "locality": "locality",
    "postal_code": "postal_code",
    "valid_till": "valid_till",
    "latitude": "latitude",
    "longitude": "longitude",
    "image_url": "image_url",
}


def _get_asset_or_404(db: Session, tenant_id: int, asset_id: int) -> Asset:
    """
    Retrieves an asset by ID and ensures it belongs to the specified tenant.
    Raises a 404 error if not found or if the asset is marked as deleted.
    """
    asset = (
        db.query(Asset)
        .filter(Asset.id == asset_id, Asset.tenant_id == tenant_id, Asset.is_deleted == False)
        .first()
    )
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")
    return asset


def _default_department(db: Session, tenant_id: int) -> Department | None:
    """
    Retrieves the system-default department ('GEN') for a tenant organization.
    """
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
    """
    Records a lifecycle event for an asset, capturing the user, their role, 
    and the asset's current geolocation.
    """
    geo = None
    if asset.latitude is not None and asset.longitude is not None:
        geo = {"lat": asset.latitude, "lng": asset.longitude}
    
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


@router.post("/", response_model=AssetResponse, status_code=status.HTTP_201_CREATED, summary="Manually Register Asset")
def create_asset(
    payload: AssetCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Registers a new physical asset in the system. 
    Requires a unique asset_token (usually from a QR code) and valid department assignment.
    """
    # Ensure token is unique for this tenant
    existing = db.query(Asset).filter(
        Asset.tenant_id == current_user.tenant_id,
        Asset.asset_token == payload.asset_token
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="This QR code is already registered.")

    # Business Logic: ALL CAPS for location fields
    city = payload.city.strip().upper() if payload.city else ""
    building = payload.building.strip().upper() if payload.building else ""
    floor = payload.floor.strip().upper() if payload.floor else None
    room = payload.room.strip().upper() if payload.room else None

    asset = Asset(
        asset_token=payload.asset_token,
        tenant_id=current_user.tenant_id,
        department_id=payload.department_id,
        asset_name=payload.asset_name.strip(),
        city=city,
        building=building,
        floor=floor,
        room=room,
        street=payload.street,
        locality=payload.locality,
        postal_code=payload.postal_code,
        latitude=payload.latitude,
        longitude=payload.longitude,
        attributes=payload.attributes,
    )
    db.add(asset)
    db.flush() # Get ID for event

    _create_event(
        db,
        asset=asset,
        event_type=AssetEventType.CREATED,
        current_user=current_user,
    )
    db.commit()
    db.refresh(asset)
    return asset


@router.get("/", response_model=list[AssetResponse], summary="List Assets")
def get_assets(
    q: Optional[str] = Query(default=None, description="Search query for name, serial, or token"),
    city: Optional[str] = Query(default=None, description="Filter by city"),
    department_id: Optional[int] = Query(default=None, description="Filter by specific department ID"),
    project_name: Optional[str] = Query(default=None, description="Filter by project name"),
    attrs: Optional[str] = Query(default=None, description="JSON string for filtering by custom attributes"),
    start_date: Optional[str] = Query(default=None, description="Start date for filtering by creation date (ISO format)"),
    end_date: Optional[str] = Query(default=None, description="End date for filtering by creation date (ISO format)"),
    sort_by: Optional[str] = Query(default="newest", description="Sort order: newest or oldest"),
    skip: int = Query(default=0, ge=0, description="Pagination skip"),
    limit: int = Query(default=100, ge=1, le=1000, description="Pagination limit"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Retrieve a list of assets for the current tenant. 
    Supports full-text search and advanced filtering by location, department, and custom attributes.
    """
    query = db.query(Asset).filter(Asset.tenant_id == current_user.tenant_id, Asset.is_deleted == False)

    if city:
        query = query.filter(Asset.city == city)

    if department_id is not None:
        query = query.filter(Asset.department_id == department_id)
        
    if project_name:
        query = query.filter(Asset.attributes["project_name"].astext == project_name)

    if attrs:
        import json
        try:
            filter_attrs = json.loads(attrs)
            for k, v in filter_attrs.items():
                if v:
                    query = query.filter(Asset.attributes[k].astext == str(v))
        except:
            pass

    if start_date:
        from datetime import datetime
        try:
            start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            query = query.filter(Asset.created_at >= start_dt)
        except ValueError:
            pass

    if end_date:
        from datetime import datetime
        try:
            end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            query = query.filter(Asset.created_at <= end_dt)
        except ValueError:
            pass

    if q and q.strip():
        like = f"%{q.strip()}%"
        query = query.filter(
            or_(
                Asset.asset_name.ilike(like),
                Asset.serial_number.ilike(like),
                Asset.asset_token.ilike(like),
                Asset.city.ilike(like),
                Asset.building.ilike(like),
            )
        )

    if sort_by == "oldest":
        query = query.order_by(Asset.created_at.asc())
    else:
        query = query.order_by(Asset.created_at.desc())

    return query.offset(skip).limit(limit).all()


@router.get("/stats", response_model=AssetStatsResponse)
def get_asset_stats(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    base_query = db.query(Asset).filter(Asset.tenant_id == current_user.tenant_id, Asset.is_deleted == False)
    total_assets = base_query.count()
    # Only return cities that have at least one asset
    cities = [r[0] for r in db.query(distinct(Asset.city)).filter(
        Asset.tenant_id == current_user.tenant_id, 
        Asset.is_deleted == False,
        Asset.city != None,
        Asset.city != ""
    ).all()]

    # Extract unique project names
    project_names = [r[0] for r in db.query(distinct(Asset.attributes["project_name"].astext)).filter(
        Asset.tenant_id == current_user.tenant_id,
        Asset.is_deleted == False,
        Asset.attributes["project_name"] != None,
        Asset.attributes["project_name"].astext != ""
    ).all()]

    return AssetStatsResponse(
        total_assets=total_assets,
        cities=cities,
        project_names=project_names,
    )


@router.get("/dropdowns", response_model=AssetDropdownsResponse)
def get_dropdowns(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    from sqlalchemy import func
    tenant_id = current_user.tenant_id
    
    def get_unique_upper(field):
        return [r[0] for r in db.query(distinct(func.upper(field))).filter(
            Asset.tenant_id == tenant_id, 
            Asset.is_deleted == False,
            field != None,
            field != ""
        ).all()]

    asset_names = [r[0] for r in db.query(distinct(Asset.asset_name)).filter(
        Asset.tenant_id == tenant_id,
        Asset.is_deleted == False,
        Asset.asset_name != None,
        Asset.asset_name != ""
    ).all()]

    # Extract all distinct key-value pairs from the JSONB attributes in a single optimized query
    custom_attr_dropdowns = {}
    from sqlalchemy import text
    try:
        query = text("""
            SELECT key, val 
            FROM assets, jsonb_each_text(attributes) AS kv(key, val)
            WHERE tenant_id = :tid AND is_deleted = FALSE 
            GROUP BY key, val
        """)
        res = db.execute(query, {"tid": tenant_id})
        for row in res.fetchall():
            k, v = row[0], row[1]
            if v and v.strip():
                if k not in custom_attr_dropdowns:
                    custom_attr_dropdowns[k] = []
                custom_attr_dropdowns[k].append(v)
                
        for k in custom_attr_dropdowns:
            custom_attr_dropdowns[k] = sorted(list(set(custom_attr_dropdowns[k])))
    except Exception as e:
        import logging
        logging.error(f"Error fetching custom dropdowns: {e}")

    # Ensure project_name is always present if it exists in attributes
    project_names = custom_attr_dropdowns.get("project_name", [])

    return AssetDropdownsResponse(
        cities=sorted(get_unique_upper(Asset.city)),
        buildings=sorted(get_unique_upper(Asset.building)),
        floors=sorted(get_unique_upper(Asset.floor)),
        rooms=sorted(get_unique_upper(Asset.room)),
        asset_names=sorted(asset_names),
        project_names=sorted(project_names),
        statuses=custom_attr_dropdowns.get("asset_status", []),
        conditions=custom_attr_dropdowns.get("asset_condition", []),
        custom_attributes=custom_attr_dropdowns
    )


@router.get("/by-qr/{token}", response_model=AssetResponse, summary="Lookup Asset by QR")
def get_asset_by_qr(
    token: str,
    response: Response,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Fetch asset details using a QR token. 
    If the token is unrecognized, a new asset is automatically initialized and assigned to the 'General' department.
    Returns 201 if a new asset was created, 200 if an existing one was found.
    """
    asset = (
        db.query(Asset)
        .filter(
            Asset.tenant_id == current_user.tenant_id,
            Asset.asset_token == token
        )
        .first()
    )
    
    if not asset:
        # 1. Find the General department for this tenant
        gen_dept = db.query(Department).filter(
            Department.tenant_id == current_user.tenant_id,
            Department.code == DEFAULT_DEPARTMENT_CODE
        ).first()

        # 2. AUTO-CREATE
        asset = Asset(
            asset_token=token,
            tenant_id=current_user.tenant_id,
            department_id=gen_dept.id if gen_dept else None,
            asset_name="", # Start empty
            attributes={},
        )
        db.add(asset)
        db.flush()
        
        _create_event(
            db,
            asset=asset,
            event_type=AssetEventType.CREATED,
            current_user=current_user,
        )
        db.commit()
        db.refresh(asset)
        response.status_code = status.HTTP_201_CREATED
        
    return asset


@router.get("/{asset_id}", response_model=AssetResponse)
def get_asset(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    if not current_user.permissions.get("view_assets"):
        raise HTTPException(status_code=403, detail="Missing permission: view_assets")
    return _get_asset_or_404(db, current_user.tenant_id, asset_id)


@router.patch("/{asset_id}", response_model=AssetResponse, summary="Update Asset Details")
def update_asset(
    asset_id: int,
    payload: AssetUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Update an existing asset's core fields or custom attributes.
    Location strings (City, Building, etc.) are automatically normalized to uppercase.
    Custom attributes provided in the payload are merged with existing ones.
    """
    import logging
    logger = logging.getLogger(__name__)

    if not current_user.permissions.get("edit_assets"):
        raise HTTPException(status_code=403, detail="Missing permission: edit_assets")

    asset = _get_asset_or_404(db, current_user.tenant_id, asset_id)
    logger.debug(f"Updating asset {asset_id}. Payload: {payload.model_dump(exclude_unset=True)}")

    # Business Logic: ALL CAPS for location fields
    if payload.city: payload.city = payload.city.strip().upper()
    if payload.building: payload.building = payload.building.strip().upper()
    if payload.floor: payload.floor = payload.floor.strip().upper()
    if payload.room: payload.room = payload.room.strip().upper()

    dump = payload.model_dump(exclude_unset=True)
    for field, value in dump.items():
        if field == "attributes" and value is not None:
            merged = dict(asset.attributes or {})
            merged.update(value)
            asset.attributes = merged
            logger.debug(f"Updated attributes: {asset.attributes}")
        elif field == "image_base64" and value:
            asset.image_url = value
        elif field in CORE_FIELD_MAP:
            setattr(asset, field, value)
            logger.debug(f"Updated {field} to {value}")

    try:
        db.commit()
        db.refresh(asset)
        logger.debug(f"Asset {asset_id} committed successfully. New name: {asset.asset_name}")
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to commit asset {asset_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Database error: {e}")
        
    return asset


@router.delete("/{asset_id}", summary="Delete Asset")
def delete_asset(
    asset_id: int,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Soft-deletes an asset. Preserves the asset and its event history for audit trails
    but removes it from all active queries and lists.
    """
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Only admins can delete assets")

    asset = _get_asset_or_404(db, current_user.tenant_id, asset_id)
    
    # Soft delete
    asset.is_deleted = True
    
    # Log the deletion event
    _create_event(db, asset=asset, event_type=AssetEventType.DELETED, current_user=current_user)
    
    db.commit()
    return {"status": "success", "message": "Asset successfully soft-deleted"}


from app.services.jwt_tokens import decode_token

@router.get("/{asset_id}/image", summary="Direct Image Access")
def get_asset_image(
    asset_id: int,
    image_token: str = Query(..., description="A specialized token for image access"),
    db: Session = Depends(get_db),
):
    """
    Directly serve the binary image data for an asset using a secure, time-bound image token.
    """
    try:
        payload = decode_token(image_token)
        if payload.get("type") != "image_access":
            raise HTTPException(status_code=403, detail="Invalid token type")
        if payload.get("asset_id") != asset_id:
            raise HTTPException(status_code=403, detail="Token not authorized for this asset")
        tenant_id = payload.get("tenant_id")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired image token")

    asset = _get_asset_or_404(db, tenant_id, asset_id)
    if not asset.image_url:
        raise HTTPException(status_code=404, detail="No image for this asset")
    
    try:
        # Expected format: "data:image/jpeg;base64,..."
        if "," in asset.image_url:
            header, encoded = asset.image_url.split(",", 1)
            # Extract mime type: data:image/jpeg;base64 -> image/jpeg
            mime_type = header.split(";")[0].split(":", 1)[1]
            data = base64.b64decode(encoded)
            return Response(content=data, media_type=mime_type)
        else:
            # Fallback for raw base64 or other formats
            data = base64.b64decode(asset.image_url)
            return Response(content=data, media_type="image/jpeg")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error decoding image: {str(e)}")


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
