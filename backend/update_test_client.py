import os
import json
import sys
import uuid
from sqlalchemy.orm import Session

# Add current directory to path
sys.path.append(os.getcwd())

from app.db import Sessionlocal
from app.models.tenant import Tenant
from app.models.role_type import RoleType
from app.models.user import User
from app.models.asset import Asset
from app.models.asset_event import AssetEvent, AssetEventType
from app.models.department import Department, DepartmentFieldDefinition
from app.schemas.admin import DEFAULT_PERMISSIONS
from app.utils.security import hash_password

def update_hierarchy_and_assets():
    db = Sessionlocal()
    try:
        # 1. Correct Hierarchy
        u1 = db.query(User).filter(User.username == 'admin@goagile.com').first()
        if u1:
            u1.is_superadmin = True
            print("Set admin@goagile.com as SuperAdmin")
        
        u2 = db.query(User).filter(User.username == 'test@goagile.com').first()
        if u2:
            u2.is_superadmin = False
            print("Set test@goagile.com as regular Admin")

        # 2. Find Test Tenant
        tenant = db.query(Tenant).filter(Tenant.code == "TEST").first()
        if not tenant:
            print("Test Tenant not found.")
            return

        # 3. Seed Assets from JSON (Allowing duplicate names)
        # ABSOLUTE PATH FIXED
        json_path = "/Users/shayanfahimi/Downloads/Final-Asset register -Updated-WH&WS.json"
        
        if os.path.exists(json_path):
            print(f"Loading data from {json_path}...")
            with open(json_path, 'r') as f:
                data = json.load(f)
            
            # Wipe existing assets for this tenant to re-seed cleanly
            db.query(AssetEvent).filter(AssetEvent.tenant_id == tenant.id).delete()
            db.query(Asset).filter(Asset.tenant_id == tenant.id).delete()
            print("Wiped old data for clean re-seed.")

            total_assets = 0
            for dept_name, items in data.items():
                dept = db.query(Department).filter(Department.tenant_id == tenant.id, Department.name == dept_name[:50]).first()
                if not dept: 
                    dept = Department(tenant_id=tenant.id, name=dept_name[:50], code=dept_name[:3].upper())
                    db.add(dept)
                    db.flush()
                    
                    # Add custom fields to every department
                    base_fields = [
                        ("asset_name", "Asset Name", "dropdown", True, 1),
                        ("asset_description", "Asset Description", "text", False, 2),
                        ("asset_status", "Asset Status", "dropdown", True, 3),
                        ("asset_condition", "Asset Condition", "dropdown", True, 4),
                        ("reference", "Physical Reference", "text", False, 5),
                    ]
                    for key, label, ftype, req, order in base_fields:
                        db.add(DepartmentFieldDefinition(
                            department_id=dept.id, field_key=key, label=label,
                            field_type=ftype, required=req, visible_when_blank=False,
                            editable_by_roles=["Admin", "Worker"], display_order=order
                        ))
                    print(f"Created Department: {dept.name}")
                
                for item in items:
                    asset_name = item.get("Job Plan", "Unnamed Asset")
                    asset = Asset(
                        asset_token=str(uuid.uuid4()),
                        tenant_id=tenant.id,
                        department_id=dept.id,
                        asset_name=asset_name,
                        building=str(item.get("Site", "MAIN")).upper(),
                        city="DUBAI",
                        attributes={
                            "asset_description": item.get("Description", ""),
                            "asset_status": item.get("Status", "ACTIVE"),
                            "asset_condition": "GOOD",
                            "reference": item.get("Job Plan Category", "")
                        }
                    )
                    db.add(asset)
                    total_assets += 1
            
            print(f"Finished processing. Total assets to add: {total_assets}")
        else:
            print(f"CRITICAL: JSON file not found at {json_path}")

        db.commit()
        print("Hierarchy and Assets committed successfully.")
    except Exception as e:
        db.rollback()
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    update_hierarchy_and_assets()
