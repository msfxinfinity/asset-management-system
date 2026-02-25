from app.models.role_type import RoleType
from app.models.user import User
from app.utils.security import hash_password


def _login(client, username, password):
    response = client.post(
        "/auth/login",
        json={"username": username, "password": password},
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_worker_cannot_access_admin_routes(client, db_session):
    worker_role = (
        db_session.query(RoleType)
        .filter(RoleType.name == "Worker")
        .first()
    )
    user = User(
        tenant_id=1,
        role_type_id=worker_role.id,
        full_name="Worker User",
        username="worker2@goagile.com",
        email="worker2@goagile.com",
        password_hash=hash_password("worker123"),
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()

    headers = _login(client, "worker2@goagile.com", "worker123")
    response = client.get("/admin/roles", headers=headers)
    assert response.status_code == 403
