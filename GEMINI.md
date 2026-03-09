# GoAgile AMS: System Architecture & Handoff Report

## 1. High-Level Architecture
*   **Frontend:** Production Flutter Web.
    *   **Architecture:** Clean State Separation with `AppSession`.
    *   **Resilience:** `GlobalErrorBoundary` wrapper and `mounted` checks on all async callbacks to prevent production crashes.
    *   **Design:** Modern Dark Glassmorphism.
*   **Backend:** Python FastAPI (Uvicorn).
    *   **Database:** PostgreSQL (SQLAlchemy ORM) with JSONB for dynamic attributes.
    *   **Security:** JWT with specialized, time-bound **Image Tokens** for reporting (prevents main token leakage).
    *   **Messaging:** Asynchronous email dispatch via `BackgroundTasks`.
*   **Platform:** Fully Multi-Tenant with strict `tenant_id` isolation.

## 2. Windows IIS & Deployment Context
*   **Environment:** The system is currently being deployed/tested on a **Windows IIS Server** via a VM.
*   **Database:** PostgreSQL 14+ running on `localhost:5432` (Database: `assetdb`).
*   **Current URLs:**
    *   **Backend API:** `http://localhost:8000` (mapped via reverse proxy if accessing through port 80).
    *   **Frontend Web:** `http://localhost:8080` (hosted on IIS).
    *   **Health Check:** `http://localhost:8000/health`.
*   **Configuration:** `.env` is located in `backend/` and contains production SMTP/IMAP credentials.

## 3. Critical Logic Updates (v1.0.6)
*   **Impersonation Removed:** The "Enter Organization" system was fully purged. SuperAdmins now have direct visibility of tenant admin credentials in the "Platform" section for troubleshooting.
*   **Mail Configuration:** SMTP and IMAP are now manually configurable per tenant. The system defaults to Organizational settings, falling back to `.env` only if explicitly configured in `bootstrap.py`.
*   **Asset Management:**
    *   "Asset Status" and "Asset Condition" are now **Core Fields** available in the edit modal.
    *   Dropdowns for Project, City, and Building are dynamically populated and group-optimized (raw SQL) for performance.
*   **Reporting:** CSV exports now include the **Locality** column and **Secure Image Links** that work externally without revealing the user's main session token.

## 4. Maintenance Guidelines for Next Instance
*   **Dependency Management:** Always use `pip install -r requirements.txt` after pulling. New production dependencies added: `python-dotenv`, `bcrypt`, `email-validator`, `python-multipart`.
*   **Database Schema:** New column `initial_admin_password` and IMAP fields added to `tenants` table.
*   **Frontend Rebuild:** After UI changes, run `flutter clean` then `flutter build web --release`. Ensure the artifacts are copied to the IIS directory.
*   **Git Integrity:** Do NOT push `.env`, `venv/`, or `build/` folders. These are blacklisted in the root `.gitignore`.

## 5. Current Task Status
*   **[COMPLETED]** Production Security Hardening (JWT Image Tokens).
*   **[COMPLETED]** N+1 Query Optimization for dropdowns.
*   **[COMPLETED]** Per-tenant IMAP configuration support.
*   **[COMPLETED]** Global Error Handling (Frontend safety net).
*   **[COMPLETED]** Multi-tenant 'General' department synchronization.
*   **[PENDING]** Implementation of logic to actually parse incoming IMAP support emails into tickets.
*   **[PENDING]** Finalizing mobile app build for store release.

---
**Note to next Gemini:** The user is currently validating the Windows IIS setup. Ensure all API calls from the frontend respect the `API_BASE_URL` and that the backend is started with `python -m app.main` from the `backend/` directory.
