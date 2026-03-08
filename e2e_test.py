import urllib.request
import urllib.parse
import json
import uuid
import base64
import sys
import time
from datetime import datetime, timedelta

BASE_URL = "http://localhost:8000"

def do_req(method, endpoint, data=None, token=None, tenant_id=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if tenant_id:
        headers["X-Tenant-Id"] = str(tenant_id)
        
    req_data = None
    if data is not None:
        req_data = json.dumps(data).encode('utf-8')
        headers["Content-Type"] = "application/json"
        
    url = f"{BASE_URL}{endpoint}"
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as response:
            status = response.status
            body = response.read()
            if body:
                return status, json.loads(body.decode('utf-8'))
            return status, None
    except urllib.error.HTTPError as e:
        body = e.read()
        try:
            return e.code, json.loads(body.decode('utf-8'))
        except:
            return e.code, body.decode('utf-8')
    except Exception as e:
        return 0, str(e)

def print_step(msg):
    print(f"\n[{msg}]")

def run_test():
    # 1. Login as SuperAdmin
    print_step("1. Login as Admin")
    status, res = do_req("POST", "/auth/login", {"username": "admin@goagile.com", "password": "goagile123"})
    assert status == 200, f"Login failed: {status} {res}"
    token = res["access_token"]
    print("Login successful. Token acquired.")

    # 2. Verify Home Page Stats
    print_step("2. Fetch Home Page Stats")
    status, res = do_req("GET", "/assets/stats", token=token)
    assert status == 200, f"Stats failed: {status} {res}"
    print(f"Stats: {res}")

    # 3. Create Departments A, B, C, D
    print_step("3. Create Departments A, B, C, D")
    depts = {}
    for name, code in [("Dept A", "DEPTA"), ("Dept B", "DEPTB"), ("Dept C", "DEPTC"), ("Dept D", "DEPTD")]:
        status, res = do_req("POST", "/admin/departments", {"name": name, "code": code}, token=token)
        assert status == 201, f"Failed to create dept {name}: {status} {res}"
        depts[code] = res
        print(f"Created {name} with ID {res['id']}")

    # 3b. Edge case: Duplicate Department Code
    status, res = do_req("POST", "/admin/departments", {"name": "Duplicate", "code": "DEPTA"}, token=token)
    assert status == 409, f"Duplicate dept should fail with 409, got: {status} {res}"
    print("Duplicate department caught successfully.")

    # 3c. Edge case: Try to delete GEN department
    status, all_depts = do_req("GET", "/admin/departments", token=token)
    gen_dept = next((d for d in all_depts if d["code"] == "GEN"), None)
    if gen_dept:
        status, res = do_req("DELETE", f"/admin/departments/{gen_dept['id']}", token=token)
        assert status == 400, f"Deleting GEN dept should fail with 400, got: {status} {res}"
        print("GEN department deletion prevented successfully.")

    # 4. Add unique fields to A, B, C
    print_step("4. Add unique fields to A, B, C")
    for code, f_key in [("DEPTA", "field_a"), ("DEPTB", "field_b"), ("DEPTC", "field_c")]:
        d_id = depts[code]["id"]
        status, fields = do_req("GET", f"/admin/departments/{d_id}/fields", token=token)
        fields.append({
            "department_id": d_id,
            "field_key": f_key,
            "label": f"Unique {code}",
            "field_type": "string",
            "required": False,
            "visible_when_blank": True,
            "editable_by_roles": ["Admin", "Worker"],
            "display_order": len(fields) + 1
        })
        status, res = do_req("PUT", f"/admin/departments/{d_id}/fields", {"fields": fields}, token=token)
        assert status == 200, f"Failed to add field to {code}: {status} {res}"
        print(f"Added unique field {f_key} to {code}")

    # 5. Delete Department D
    print_step("5. Delete Department D")
    d_id = depts["DEPTD"]["id"]
    status, res = do_req("DELETE", f"/admin/departments/{d_id}", token=token)
    assert status in [200, 204], f"Failed to delete Dept D: {status} {res}"
    print("Deleted Dept D successfully (No ClientException!)")

    # 6. Scan 10 assets and Edit
    print_step("6. Scan and Edit 10 Assets")
    assets = []
    dept_choices = [depts["DEPTA"]["id"], depts["DEPTB"]["id"], depts["DEPTC"]["id"]]
    project_choices = ["Project Alpha", "Project Beta"]
    
    dummy_image = "data:image/jpeg;base64," + base64.b64encode(b"dummy_image_data").decode('utf-8')

    for i in range(10):
        qr_token = f"QR-TEST-{uuid.uuid4().hex[:8]}"
        status, res = do_req("GET", f"/assets/by-qr/{qr_token}", token=token)
        assert status == 201, f"Failed to scan/create QR: {status} {res}"
        a = res
        
        dept_id = dept_choices[i % 3]
        proj = project_choices[i % 2]
        
        custom_attrs = {"project_name": proj}
        if dept_id == depts["DEPTA"]["id"]: custom_attrs["field_a"] = f"Value A {i}"
        if dept_id == depts["DEPTB"]["id"]: custom_attrs["field_b"] = f"Value B {i}"
        if dept_id == depts["DEPTC"]["id"]: custom_attrs["field_c"] = f"Value C {i}"

        update_payload = {
            "department_id": dept_id,
            "asset_name": f"Test Asset {i}",
            "city": "TEST CITY",
            "building": "TEST BUILDING",
            "latitude": 24.123,
            "longitude": 46.123,
            "image_base64": dummy_image,
            "attributes": custom_attrs
        }
        status, res = do_req("PATCH", f"/assets/{a['id']}", update_payload, token=token)
        assert status == 200, f"Failed to patch asset {i}: {status} {res}"
        assets.append(res)
        print(f"Scanned and saved Asset {i} (ID: {a['id']}, Dept: {dept_id}, Proj: {proj})")

    # 7. Scan an existing QR
    print_step("7. Scan existing QR")
    existing_qr = assets[0]["asset_token"]
    status, res = do_req("GET", f"/assets/by-qr/{existing_qr}", token=token)
    assert status == 200, f"Failed to fetch existing QR: {status} {res}"
    print("Successfully fetched existing asset via QR")

    # 8. Verify Details of 10 assets
    print_step("8. Verify Details of 10 Assets")
    for a in assets:
        status, fetched = do_req("GET", f"/assets/{a['id']}", token=token)
        assert status == 200, f"Failed to get asset {a['id']}"
        assert fetched["asset_name"] is not None
        assert fetched["department_id"] is not None
        assert fetched["city"] == "TEST CITY"
        assert "project_name" in fetched["attributes"]
    print("All 10 assets verified successfully. Details present.")

    # 9. Delete 1 asset
    print_step("9. Delete Asset")
    to_delete = assets.pop()
    status, res = do_req("DELETE", f"/assets/{to_delete['id']}", token=token)
    assert status in [200, 204], f"Failed to delete asset: {status} {res}"
    print(f"Deleted asset {to_delete['id']} successfully.")

    # 10. Test Filtering
    print_step("10. Test Filtering")
    status, res = do_req("GET", "/assets/?" + urllib.parse.urlencode({"city": "TEST CITY"}), token=token)
    assert status == 200
    print(f"Filter by City returned {len(res)} assets")
    
    status, res = do_req("GET", "/assets/?" + urllib.parse.urlencode({"department_id": depts['DEPTA']['id']}), token=token)
    print(f"Filter by Dept A returned {len(res)} assets")
    
    status, res = do_req("GET", "/assets/?" + urllib.parse.urlencode({"project_name": "Project Alpha"}), token=token)
    print(f"Filter by Project Alpha returned {len(res)} assets")
    
    attrs_filter = json.dumps({"field_a": "Value A 0"})
    status, res = do_req("GET", "/assets/?" + urllib.parse.urlencode({"attrs": attrs_filter}), token=token)
    print(f"Filter by Custom Attr 'field_a' returned {len(res)} assets")

    # 11. Create & Delete Roles
    print_step("11. Create & Delete Roles")
    status, res = do_req("POST", "/admin/roles", {"name": "Test Role", "permissions": {"view_assets": True}}, token=token)
    assert status == 201, f"Failed to create role: {status} {res}"
    role_id = res["id"]
    print(f"Created Role ID {role_id}")
    
    status, res = do_req("DELETE", f"/admin/roles/{role_id}", token=token)
    assert status in [200, 204], f"Failed to delete role: {status} {res}"
    print("Deleted Role successfully")

    # 12. Create & Delete Users
    print_step("12. Create & Delete Users")
    status, res = do_req("GET", "/admin/roles", token=token)
    assert status == 200, f"Failed to get roles: {status} {res}"
    try:
        worker_role_id = next(r["id"] for r in res if r["name"] == "Worker")
    except StopIteration:
        raise Exception(f"Worker role not found in {res}")
    
    status, res = do_req("POST", "/admin/users", {
        "full_name": "Test User",
        "username": "testuser",
        "email": "testuser@example.com",
        "role_type_id": worker_role_id,
        "password": "password123"
    }, token=token)
    assert status == 201, f"Failed to create user: {status} {res}"
    user_id = res["id"]
    print(f"Created User ID {user_id}")

    # Edge case: Test password update
    print_step("12b. Test User Password Update")
    status, res = do_req("POST", f"/admin/users/{user_id}/reset-password", {"password": "newpassword456"}, token=token)
    assert status == 200, f"Failed to reset password: {status} {res}"
    
    # Try logging in with the new password
    status, res = do_req("POST", "/auth/login", {"username": "testuser", "password": "newpassword456"})
    assert status == 200, f"Failed to login with new password: {status} {res}"
    print("User password updated and verified successfully.")

    # Edge case: Delete self
    status, res = do_req("DELETE", "/admin/users/1", token=token) # admin@goagile.com is id=1
    assert status in [400, 403], f"Should not be able to delete self/primary admin, got {status} {res}"
    print("Self-deletion prevented.")

    status, res = do_req("DELETE", f"/admin/users/{user_id}", token=token)
    assert status in [200, 204], f"Failed to delete user: {status} {res}"
    print("Deleted User successfully")

    # 13. Create New Tenant
    print_step("13. Create New Tenant & Verify")
    status, res = do_req("POST", "/superadmin/tenants", {
        "name": "New Tenant Corp",
        "code": "NTC",
        "admin_email": "admin@ntc.com",
        "admin_password": "password"
    }, token=token)
    assert status == 201, f"Tenant creation failed: {status} {res}"
    print(f"Created New Tenant ID {res['id']}")

    status, res = do_req("POST", "/auth/login", {"username": "admin@ntc.com", "password": "password"})
    assert status == 200, f"Tenant login failed: {status} {res}"
    tenant_token = res["access_token"]
    
    status, t_depts = do_req("GET", "/admin/departments", token=tenant_token)
    gen_dept = next((d for d in t_depts if d["code"] == "GEN"), None)
    assert gen_dept is not None, "General department not found for new tenant!"
    print(f"Verified General template exists for new tenant (Dept ID {gen_dept['id']})")
    
    # 14. Full Lifecycle Test for New Tenant
    print_step("14. Full Lifecycle Test for New Tenant")
    # Create Departments for Tenant
    t_depts_map = {}
    for name, code in [("Tenant Dept X", "DEPTX"), ("Tenant Dept Y", "DEPTY")]:
        status, res = do_req("POST", "/admin/departments", {"name": name, "code": code}, token=tenant_token)
        assert status == 201, f"Failed to create tenant dept {name}: {status} {res}"
        t_depts_map[code] = res
        print(f"Created Tenant Dept {name} with ID {res['id']}")
        
    # Add multiple custom fields to DEPTX
    d_x_id = t_depts_map["DEPTX"]["id"]
    status, fields = do_req("GET", f"/admin/departments/{d_x_id}/fields", token=tenant_token)
    fields.extend([
        {
            "department_id": d_x_id, "field_key": "t_field_1", "label": "Tenant Field 1",
            "field_type": "string", "required": True, "visible_when_blank": True,
            "editable_by_roles": ["Admin"], "display_order": len(fields) + 1
        },
        {
            "department_id": d_x_id, "field_key": "t_field_2", "label": "Tenant Field 2",
            "field_type": "number", "required": False, "visible_when_blank": True,
            "editable_by_roles": ["Admin"], "display_order": len(fields) + 2
        }
    ])
    status, res = do_req("PUT", f"/admin/departments/{d_x_id}/fields", {"fields": fields}, token=tenant_token)
    assert status == 200, f"Failed to add fields to Tenant Dept X: {status} {res}"
    print("Added multiple custom fields to Tenant Dept X")
    
    # Scan and Save for Tenant
    qr_token = f"QR-NTC-{uuid.uuid4().hex[:8]}"
    status, ntc_asset = do_req("GET", f"/assets/by-qr/{qr_token}", token=tenant_token)
    assert status == 201
    assert ntc_asset["department_id"] == gen_dept["id"], "New asset did not auto-assign to General department!"
    
    t_update_payload = {
        "department_id": d_x_id,
        "asset_name": "Tenant Asset 1",
        "city": "TENANT CITY",
        "attributes": {
            "project_name": "Tenant Project Alpha",
            "t_field_1": "Custom Value 1",
            "t_field_2": 42
        }
    }
    status, res = do_req("PATCH", f"/assets/{ntc_asset['id']}", t_update_payload, token=tenant_token)
    assert status == 200, f"Failed to patch tenant asset: {status} {res}"
    
    # Filter for Tenant
    status, res = do_req("GET", "/assets/?" + urllib.parse.urlencode({"city": "TENANT CITY"}), token=tenant_token)
    assert status == 200 and len(res) == 1, "Tenant filtering by city failed"
    
    t_attrs_filter = json.dumps({"t_field_2": 42})
    status, res = do_req("GET", "/assets/?" + urllib.parse.urlencode({"attrs": t_attrs_filter}), token=tenant_token)
    assert status == 200 and len(res) == 1, "Tenant filtering by custom attr failed"
    print("Tenant asset creation, custom fields, and filtering verified.")

    print("\n✅ ALL TESTS PASSED SUCCESSFULLY! No ClientExceptions. Features working as expected.")

if __name__ == "__main__":
    try:
        run_test()
    except Exception as e:
        print(f"\n❌ TEST FAILED: {e}")
        sys.exit(1)
