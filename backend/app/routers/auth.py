from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import CurrentUser, get_current_user
from app.models.role_type import RoleType
from app.models.user import User
from app.schemas.auth import (
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    LoginResponse,
    UserProfileResponse,
)
from app.services.jwt_tokens import issue_token
from app.utils.security import verify_password

router = APIRouter(prefix="/auth", tags=["Auth"])


def _profile_from_user(db: Session, user: User) -> UserProfileResponse:
    role = (
        db.query(RoleType)
        .filter(RoleType.id == user.role_type_id, RoleType.tenant_id == user.tenant_id)
        .first()
    )
    if not role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User role not available",
        )
    return UserProfileResponse(
        id=user.id,
        full_name=user.full_name,
        username=user.username,
        email=user.email,
        role=role.name,
        permissions=role.permissions or {},
    )


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = (
        db.query(User)
        .filter(
            or_(
                User.username == payload.username.strip().lower(),
                User.email == payload.username.strip().lower(),
            )
        )
        .first()
    )
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    profile = _profile_from_user(db, user)
    token = issue_token(user_id=user.id, tenant_id=user.tenant_id)
    return LoginResponse(access_token=token, user=profile)


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(payload: ForgotPasswordRequest):
    _ = payload
    return ForgotPasswordResponse(
        message="If the account exists, password reset instructions have been sent."
    )


@router.get("/me", response_model=UserProfileResponse)
def me(
    current_user: CurrentUser = Depends(get_current_user),
):
    return UserProfileResponse(
        id=current_user.id,
        full_name=current_user.full_name,
        username=current_user.username,
        email=current_user.email,
        role=current_user.role_name,
        permissions=current_user.permissions,
    )
