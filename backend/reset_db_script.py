from sqlalchemy import text
from app.db import engine, Base, Sessionlocal
from app.models.tenant import Tenant
from app.models.user import User
from app.models.role_type import RoleType
from app.models.asset import Asset
from app.models.asset_event import AssetEvent
from app.models.department import Department, DepartmentFieldDefinition

def sync_sequences():
    print("Syncing sequences...")
    db = Sessionlocal()
    tables = ["tenants", "users", "role_types", "departments", "department_field_definitions", "assets", "asset_events"]
    for t in tables:
        sql = f"SELECT setval('{t}_id_seq', COALESCE((SELECT MAX(id)+1 FROM {t}), 1), false);"
        try:
            db.execute(text(sql))
            db.commit()
        except Exception as e:
            db.rollback()
            print(f"Failed to sync {t}: {e}")
    db.close()
    print("Sequences synced.")

def reset_db():
    print("Dropping tables with CASCADE...")
    with engine.connect() as conn:
        tables = [
            "asset_events", "qr_batch_items", "qr_batches", "assets", 
            "department_field_definitions", "departments", "users", 
            "role_types", "tenants"
        ]
        for table in tables:
            conn.execute(text(f"DROP TABLE IF EXISTS {table} CASCADE"))
        conn.commit()
    
    print("Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("Database reset complete.")

if __name__ == "__main__":
    reset_db()
