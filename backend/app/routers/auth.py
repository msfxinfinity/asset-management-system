import secrets
import string
import logging
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import CurrentUser, get_current_user
from app.models.user import User
from app.models.tenant import Tenant
from app.models.role_type import RoleType
from app.services.jwt_tokens import create_access_token
from app.utils.security import hash_password, verify_password
from app.services.email import send_email, SmtpConfig

router = APIRouter(prefix="/auth", tags=["Authentication"])

logger = logging.getLogger(__name__)

# --- SCHEMAS ---

class LoginRequest(BaseModel):
    """Payload for user authentication."""
    username: str
    password: str

class LoginResponse(BaseModel):
    """Successful authentication response containing the access token."""
    access_token: str
    token_type: str = "bearer"

class ForgotPasswordRequest(BaseModel):
    """Payload for initiating account recovery."""
    username: str # email or username

class ForgotPasswordResponse(BaseModel):
    """Sanitized response message for recovery requests."""
    message: str

class ProfileUpdate(BaseModel):
    """Payload for user-driven profile modifications."""
    full_name: Optional[str] = None
    profile_picture: Optional[str] = None # Base64 encoded

class ChangePasswordRequest(BaseModel):
    """Payload for secure password updates."""
    old_password: str
    new_password: str

# --- INTERNAL HELPERS ---

def _get_tenant_smtp_config(tenant: Tenant) -> SmtpConfig:
    """Constructs SMTP credentials from tenant data for system notifications."""
    return SmtpConfig(
        host=tenant.smtp_host or "",
        port=tenant.smtp_port or 0,
        user=tenant.smtp_user or "",
        password=tenant.smtp_pass or "",
        from_address=tenant.smtp_from_address or "",
        from_name=tenant.smtp_from_name or "",
        encryption=tenant.smtp_encryption or "ssl",
    )

def _profile_from_user(db: Session, user: User) -> dict:
    """Serializes a user model into a frontend-ready profile object with role context."""
    role = db.query(RoleType).filter(RoleType.id == user.role_type_id).first()
    return {
        "id": user.id,
        "tenant_id": user.tenant_id,
        "role_type_id": user.role_type_id,
        "role_name": role.name if role else "Guest",
        "full_name": user.full_name,
        "username": user.username,
        "email": user.email,
        "is_active": user.is_active,
        "is_superadmin": user.is_superadmin,
        "profile_picture": user.profile_picture,
        "permissions": role.permissions if role else {},
    }

# --- AUTHENTICATION ENDPOINTS ---

@router.post("/login", response_model=LoginResponse, summary="User Authentication Gate")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    Verifies user credentials and issues a JWT access token.
    Implements security measures like case-insensitive username lookup.
    """
    user = db.query(User).filter(User.username == payload.username.strip().lower()).first()
    
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is disabled. Please contact your administrator.",
        )

    # Issue time-bound session token
    token = create_access_token(data={"sub": str(user.id), "tenant_id": user.tenant_id})
    return LoginResponse(access_token=token)

@router.get("/me", summary="Fetch Current Session Profile")
def get_me(db: Session = Depends(get_db), current_user: CurrentUser = Depends(get_current_user)):
    """Returns the full identity profile and permission matrix for the active session."""
    user = db.query(User).filter(User.id == current_user.id).first()
    return _profile_from_user(db, user)

@router.post("/forgot-password", response_model=ForgotPasswordResponse, summary="Trigger Account Recovery")
def forgot_password(
    payload: ForgotPasswordRequest, 
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Generates a temporary password and dispatches it via email.
    SECURITY: Always returns a generic success message to prevent account enumeration.
    """
    user = db.query(User).filter(
        or_(
            User.email == payload.username.strip().lower(),
            User.username == payload.username.strip().lower(),
        )
    ).first()
    
    if user:
        # Secure Random Password Generation
        chars = string.ascii_letters + string.digits
        temp_password = "".join(secrets.choice(chars) for _ in range(8))
        
        user.password_hash = hash_password(temp_password)
        user.failed_login_attempts = 0 # Reset lockdown
        db.commit()

        tenant = db.query(Tenant).filter(Tenant.id == user.tenant_id).first()
        smtp_config = _get_tenant_smtp_config(tenant)

        if smtp_config.is_active:
            content = f"""
            <html>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e1e1e1; border-radius: 10px;">
                    <h2 style="color: #1E293B;">Account Recovery</h2>
                    <p>Hello {user.full_name},</p>
                    <p>Your account access has been reset. Please use the temporary credentials below:</p>
                    <div style="background-color: #f8fafc; padding: 15px; border-radius: 5px; margin: 20px 0;">
                        <p style="margin: 5px 0;"><strong>Username:</strong> {user.username}</p>
                        <p style="margin: 5px 0;"><strong>Temporary Password:</strong> {temp_password}</p>
                    </div>
                    <p>Please update your password immediately upon logging in via the Profile section.</p>
                    <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
                    <p style="font-size: 12px; color: #777;">&copy; 2026 GoAgile Solutions. All rights reserved.</p>
                </div>
            </body>
            </html>
            """
            
            def safe_send_recovery():
                try:
                    send_email("GoAgile AMS: Account Recovery", [user.email], content, smtp_config)
                except Exception as e:
                    logger.error(f"Account recovery email failure for {user.email}: {e}")
            
            background_tasks.add_task(safe_send_recovery)

    return ForgotPasswordResponse(
        message="If an account matches your input, recovery instructions have been dispatched to the registered email."
    )

@router.patch("/profile", summary="Self-Service Profile Update")
def update_profile(payload: ProfileUpdate, db: Session = Depends(get_db), current_user: CurrentUser = Depends(get_current_user)):
    """Allows users to modify their display name or profile avatar."""
    user = db.query(User).filter(User.id == current_user.id).first()
    if payload.full_name is not None:
        user.full_name = payload.full_name
    if payload.profile_picture is not None:
        user.profile_picture = payload.profile_picture
        
    db.commit()
    db.refresh(user)
    return _profile_from_user(db, user)

@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT, summary="Secure Password Rotation")
def change_password(payload: ChangePasswordRequest, db: Session = Depends(get_db), current_user: CurrentUser = Depends(get_current_user)):
    """Securely rotates the user's password. Validates existing password before applying changes."""
    user = db.query(User).filter(User.id == current_user.id).first()
    
    if not verify_password(payload.old_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password verification failed",
        )
    
    user.password_hash = hash_password(payload.new_password)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
