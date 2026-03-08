from dataclasses import dataclass
from typing import Optional

import jwt
from fastapi import Depends, HTTPException, Query, Header, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.models.role_type import RoleType
from app.models.user import User
from app.services.jwt_tokens import decode_token


security = HTTPBearer(auto_error=False)


@dataclass
class CurrentUser:
    id: int
    tenant_id: int
    full_name: str
    username: str
    email: str
    role_name: str
    permissions: dict
    is_superadmin: bool = False
    profile_picture: Optional[str] = None
    original_tenant_id: Optional[int] = None # Track the real tenant for auditing

    @property
    def is_admin(self) -> bool:
        return self.permissions.get("is_admin", False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    access_token: Optional[str] = Query(default=None),
    x_tenant_id: Optional[int] = Header(None), # Allow impersonation via header
    db: Session = Depends(get_db),
) -> CurrentUser:
    token = credentials.credentials if credentials is not None else access_token
    if token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization token",
        )

    try:
        payload = decode_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
        ) from None
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from None

    user_id = payload.get("sub")
    real_tenant_id = payload.get("tenant_id")
    if not user_id or not real_tenant_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    user = (
        db.query(User)
        .filter(
            User.id == int(user_id),
            User.tenant_id == int(real_tenant_id),
            User.is_active.is_(True),
        )
        .first()
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not available",
        )

    # IMPERSONATION LOGIC: REMOVED (As requested)
    effective_tenant_id = real_tenant_id

    role = (
        db.query(RoleType)
        .filter(
            RoleType.id == user.role_type_id,
            RoleType.tenant_id == user.tenant_id,
        )
        .first()
    )
    if not role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Role not available",
        )

    return CurrentUser(
        id=user.id,
        tenant_id=effective_tenant_id, # Use impersonated tenant ID
        full_name=user.full_name,
        username=user.username,
        email=user.email,
        role_name=role.name,
        permissions=role.permissions or {},
        is_superadmin=user.is_superadmin,
        profile_picture=user.profile_picture,
        original_tenant_id=real_tenant_id,
    )


def require_permission(permission_key: str):
    def _guard(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if current_user.permissions.get(permission_key):
            return current_user
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Missing permission: {permission_key}",
        )

    return _guard
