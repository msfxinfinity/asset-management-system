from sqlalchemy import text
from app.db import Sessionlocal
from app.models.tenant import Tenant
from app.models.user import User
from app.models.role_type import RoleType
from app.models.department import Department, DepartmentFieldDefinition
from app.models.asset import Asset
from app.models.asset_event import AssetEvent

def sync():
    db = Sessionlocal()
    tables = ["tenants", "users", "role_types", "departments", "department_field_definitions", "assets", "asset_events"]
    for t in tables:
        # For Postgres to update the sequence to the MAX(id)
        sql = f"SELECT setval('{t}_id_seq', COALESCE((SELECT MAX(id)+1 FROM {t}), 1), false);"
        try:
            db.execute(text(sql))
            db.commit()
            print(f"Synced sequence for {t}")
        except Exception as e:
            db.rollback()
            print(f"Failed to sync {t}: {e}")
    db.close()

if __name__ == "__main__":
    sync()
