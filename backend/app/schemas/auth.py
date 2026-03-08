from pydantic import BaseModel, EmailStr
from typing import Optional


class LoginRequest(BaseModel):
    username: str
    password: str


class ForgotPasswordRequest(BaseModel):
    username: str


class ForgotPasswordResponse(BaseModel):
    message: str


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


class UserCheckResponse(BaseModel):
    exists: bool
    full_name: Optional[str] = None
    profile_picture: Optional[str] = None


class UserProfileResponse(BaseModel):
    id: int
    full_name: str
    username: str
    email: EmailStr
    role: str
    permissions: dict
    is_superadmin: bool = False
    profile_picture: Optional[str] = None


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserProfileResponse
