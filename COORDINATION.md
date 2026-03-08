# AMS Development Coordination

## CURRENT STATUS: v1.0.5 - Data Overhaul Complete
**Active Build:** Production Web Build (v1.0.5)
**URL:** http://localhost:8080/
**Backend:** http://localhost:8000/

## CRITICAL LOGIN INFO
*   **SuperAdmin:** `admin@goagile.com` / `goagile123`
*   **Test Tenant Admin:** `test@goagile.com` / `goagile123`

## RECENT TECHNICAL FIXES
1.  **Indentation Fixed:** Resolved `IndentationError` in `admin.py`.
2.  **DB Schema Synced:** Re-seeded database to include `smtp_host`, `app_url`, etc.
3.  **UI Sync:** Used Python script to force-update `main.dart` UI elements (Profile Button, Filter Row).
4.  **IP Consistency:** Default `baseUrl` set to `localhost` for better camera compatibility.

## ARCHITECTURE NOTES FOR NEXT INSTANCE
*   **Multi-tenancy:** Always filter by `tenant_id`. Do not create separate tables for new tenants.
*   **Attributes:** Use `Asset.attributes` JSONB for dynamic fields.
*   **Email:** Use `send_email` in `app.services.email` which now requires an `SmtpConfig` object.
*   **User Safety:** Primary admins (ID lowest for tenant) and `admin@goagile.com` must have disabled delete buttons in UI.

## DEPLOYMENT COMMANDS
```bash
# Restart Backend
source .venv/bin/activate && cd backend && export PYTHONPATH=$PYTHONPATH:. && nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > server.log 2>&1 &

# Restart Frontend
cd frontend/build/web && nohup python3 -m http.server 8080 --bind 0.0.0.0 > ../../server.log 2>&1 &
```
