# AMS Development Coordination

## CURRENT STATUS: v1.0.6 - Production Readiness Hardening
**Active Build:** Production Web Build (v1.0.6)
**URL:** http://localhost:8080/ (IIS Windows)
**Backend:** http://localhost:8000/ (Uvicorn Windows)

## CRITICAL LOGIN INFO
*   **SuperAdmin:** `admin@goagile.com` / `goagile123`
*   **Database:** `assetdb` on `localhost:5432`

## RECENT TECHNICAL FIXES (v1.0.6)
1.  **Security:** Implemented time-bound Image Tokens for reports.
2.  **Impersonation:** Removed "Enter Organization" button; unmasked admin passwords for SuperAdmin troubleshooting.
3.  **UI Resilience:** Added `GlobalErrorBoundary` and `mounted` checks to prevent frontend crashes.
4.  **Backend Optimization:** Grouped dropdown extraction into a single SQL query (N+1 fix).
5.  **Mail:** Added per-tenant IMAP configuration fields.

## WINDOWS IIS DEPLOYMENT
- Code is cloned from GitHub on a Windows VM.
- `.env` must be in `backend/` directory.
- Run backend with `python -m app.main`.
- Pull latest with `git pull origin main`.

---
*Production audit complete. System is stabilized and ready for organizational onboarding.*
