# AMS System Architecture & Progress Report

## 1. System Architecture
*   **Frontend:** Flutter Web (compiled to JS/HTML/CSS).
    *   **State Management:** StatefulWidgets with a global `AppSession` object.
    *   **Routing:** Custom `AuthFlow` and `AppShell` with robust deep-link detection for recovery paths.
    *   **Theme:** Dark "Glassmorphism" UI using standard Material components with custom decorations.
*   **Backend:** Python FastAPI.
    *   **Database:** PostgreSQL (SQLAlchemy ORM).
    *   **Multi-Tenancy:** Shared-table architecture using `tenant_id` isolation for all data (Assets, Users, Roles, Departments).
    *   **Auth:** JWT-based bearer token authentication.
*   **Integration:**
    *   **Email:** Custom SMTP service per tenant (stored in `tenants` table).
    *   **Storage:** Attributes stored in JSONB for dynamic field support.

## 2. Core Logic & Data Design
*   **Tenants:** Organizations are strictly isolated. The primary "GoAgile" (ID: 1) tenant is immutable.
*   **Users:**
    *   Sole SuperAdmin: `admin@goagile.com`.
    *   Tenant Admins: Initial admin created during tenant setup. They cannot delete themselves or their primary organization record.
*   **Assets:**
    *   **Registration:** Mandatory "Discipline" (Department) selection.
    *   **Dynamic Dropdowns:** System learns from user input. New Asset Names, Cities, Buildings, etc., are automatically added to searchable dropdowns.
    *   **Attributes:** Dynamic fields (e.g., Physical Reference ID, TOG Zone) are stored in a flexible JSONB column.

## 3. Current Progress (v1.0.5 - Data Overhaul)
*   **[Completed] Data Seeding:** Successfully imported 13,747 assets for "Test Organization" mapped to 5 clean departments (`CVL`, `ELEC`, `IRRG`, `LS`, `MECH`).
*   **[Completed] SMTP Integration:** Real-time email validation (syntax + DNS + SMTP Handshake) for Welcome and Recovery emails.
*   **[Completed] UI Improvements:**
    *   Consolidated "Filter by" section in Assets screen.
    *   "Change Password" feature integrated into the Profile Card.
    *   Searchable dropdowns with visible dark-theme options.
    *   Scanner Fallback: Added "Take Photo / Upload QR" for non-HTTPS local environments.
*   **[Completed] Safety:** Greyed-out/Disabled delete buttons for protected system accounts.

## 4. Pending / Next Steps
*   [ ] Implement IMAP support for reading incoming support emails.
*   [ ] Real-time notification system for asset transfers.
*   [ ] Expand Audit Logs to include more detailed field-level changes.
