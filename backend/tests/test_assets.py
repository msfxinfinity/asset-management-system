def _login_admin(client):
    response = client.post(
        "/auth/login",
        json={"username": "admin@goagile.com", "password": "goagile123"},
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_activation_requires_required_fields(client):
    headers = _login_admin(client)

    batch_response = client.post(
        "/admin/qr-batches",
        headers=headers,
        json={"quantity": 1, "export_formats": ["pdf"]},
    )
    assert batch_response.status_code == 201
    asset_id = batch_response.json()["asset_ids"][0]

    activate_response = client.post(f"/assets/{asset_id}/activate", headers=headers)
    assert activate_response.status_code == 409

    update_response = client.patch(
        f"/assets/{asset_id}",
        headers=headers,
        json={"asset_name": "Laptop A"},
    )
    assert update_response.status_code == 200

    activate_response = client.post(f"/assets/{asset_id}/activate", headers=headers)
    assert activate_response.status_code == 200
