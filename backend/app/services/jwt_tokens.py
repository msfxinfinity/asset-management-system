import os
from datetime import datetime, timedelta, timezone

import jwt


def _jwt_secret() -> str:
    return os.getenv("JWT_SECRET", "ams-dev-secret-key-32-characters-minimum")


def _jwt_algorithm() -> str:
    return os.getenv("JWT_ALGORITHM", "HS256")


def _jwt_exp_minutes() -> int:
    return int(os.getenv("JWT_EXPIRES_MINUTES", "240"))


def issue_token(user_id: int, tenant_id: int) -> str:
    now = datetime.now(tz=timezone.utc)
    payload = {
        "sub": str(user_id),
        "tenant_id": tenant_id,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=_jwt_exp_minutes())).timestamp()),
    }
    return jwt.encode(payload, _jwt_secret(), algorithm=_jwt_algorithm())


def decode_token(token: str) -> dict:
    return jwt.decode(token, _jwt_secret(), algorithms=[_jwt_algorithm()])
