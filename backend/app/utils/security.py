import hashlib
import hmac
import os


def hash_password(password: str) -> str:
    salt = os.getenv("PASSWORD_SALT", "ams-demo-salt")
    return hashlib.sha256(f"{salt}:{password}".encode("utf-8")).hexdigest()


def verify_password(password: str, password_hash: str) -> bool:
    computed = hash_password(password)
    return hmac.compare_digest(computed, password_hash)
