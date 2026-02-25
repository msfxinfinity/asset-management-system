from app.models.role_type import RoleType
from app.models.user import User
from app.utils.security import hash_password


def _login(client, username="admin@goagile.com", password="goagile123"):
    response = client.post(
        "/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_login_and_me(client):
    headers = _login(client)
    response = client.get("/auth/me", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    assert payload["email"] == "admin@goagile.com"
    assert payload["permissions"]["is_admin"] is True


def test_worker_login(client, db_session):
    worker_role = (
        db_session.query(RoleType)
        .filter(RoleType.name == "Worker")
        .first()
    )
    user = User(
        tenant_id=1,
        role_type_id=worker_role.id,
        full_name="Worker User",
        username="worker@goagile.com",
        email="worker@goagile.com",
        password_hash=hash_password("worker123"),
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()

    response = client.post(
        "/auth/login",
        json={"username": "worker@goagile.com", "password": "worker123"},
    )
    assert response.status_code == 200
