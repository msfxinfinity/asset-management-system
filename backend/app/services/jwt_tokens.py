import os
from datetime import datetime, timedelta, timezone

import jwt


def _jwt_secret() -> str:
    return os.getenv("JWT_SECRET", "ams-dev-secret-key-32-characters-minimum")


def _jwt_algorithm() -> str:
    return os.getenv("JWT_ALGORITHM", "HS256")


def _jwt_exp_minutes() -> int:
    return int(os.getenv("JWT_EXPIRES_MINUTES", "240"))


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    now = datetime.now(tz=timezone.utc)
    to_encode.update({
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=_jwt_exp_minutes())).timestamp()),
    })
    return jwt.encode(to_encode, _jwt_secret(), algorithm=_jwt_algorithm())


def issue_reset_token(user_id: int) -> str:
    now = datetime.now(tz=timezone.utc)
    payload = {
        "sub": str(user_id),
        "type": "reset",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=15)).timestamp()),
    }
    return jwt.encode(payload, _jwt_secret(), algorithm=_jwt_algorithm())


def issue_image_token(user_id: int, tenant_id: int, asset_id: int) -> str:
    now = datetime.now(tz=timezone.utc)
    payload = {
        "sub": str(user_id),
        "tenant_id": tenant_id,
        "asset_id": asset_id,
        "type": "image_access",
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=7)).timestamp()), # 7 days valid
    }
    return jwt.encode(payload, _jwt_secret(), algorithm=_jwt_algorithm())


def decode_token(token: str) -> dict:
    return jwt.decode(token, _jwt_secret(), algorithms=[_jwt_algorithm()])
