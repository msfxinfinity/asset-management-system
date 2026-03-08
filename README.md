# GoAgile Asset Management System (AMS)

[![Production Ready](https://img.shields.io/badge/status-production--ready-success.svg)](https://goagile.com)
[![License: Open Source](https://img.shields.io/badge/license-proprietary-blue.svg)](https://goagile.com)
[![Stack: FastAPI & Flutter](https://img.shields.io/badge/stack-FastAPI%20%7C%20Flutter-blueviolet.svg)](https://goagile.com)

A high-performance, multi-tenant asset lifecycle management platform designed for industrial scalability and corporate oversight. Engineered by **GoAgile Technologies**.

---

## 🏗️ Architectural Overview

GoAgile AMS implements a **Shared-Database, Isolated-Schema** approach to multi-tenancy, ensuring strict data sovereignty while maintaining infrastructure efficiency.

### Backend (Python/FastAPI)
- **High-Concurrency:** Powered by Uvicorn and AsyncIO for non-blocking I/O.
- **Data Integrity:** PostgreSQL with SQLAlchemy ORM, utilizing JSONB for flexible, schema-less attribute storage.
- **Security:** JWT-based authentication with time-bound, scope-restricted tokens for sensitive operations (e.g., direct image access).
- **Background Processing:** Asynchronous email dispatch and notification handling via FastAPI BackgroundTasks.

### Frontend (Flutter Web)
- **State Sovereignty:** Responsive "Glassmorphism" UI built with Flutter's CanvasKit renderer.
- **Hardware Integration:** Real-time QR/Barcode scanning with optimized hardware resource management (auto-dispose camera controllers).
- **Geolocation:** Integrated GPS tracking with reverse-geocoding for automated location data entry.

---

## ✨ Enterprise Features

### 🏢 Corporate Multi-Tenancy
*   **Organizational Sandboxing:** Strict `tenant_id` isolation at the database level.
*   **Role-Based Access Control (RBAC):** Customizable permission matrices for Admins, Supervisors, and Workers.
*   **Primary Admin Protection:** Critical system accounts are protected from accidental deletion or privilege escalation.

### 📋 Intelligent Templating
*   **Dynamic Attributes:** Define custom fields per department (e.g., "TOG Zone", "Reference ID").
*   **Automated Learning:** Searchable dropdowns (City, Building, Project, Status) automatically populate from historical data.
*   **Template Inheritance:** New departments automatically inherit standardized organizational fields.

### 📲 Field Operations
*   **Zero-friction Registration:** Instant "Scan-to-Register" flow for new assets.
*   **Lifecycle Auditing:** Full historical event tracking (Generation -> Activation -> Maintenance -> Retirement).
*   **Asset Imaging:** High-fidelity base64 image capture with secure, authenticated direct-access links.

### 🔍 Advanced Reporting
*   **Customizable Filters:** Soft-coded filter UI that adapts to your organization's unique attributes.
*   **Export Engine:** Production-grade CSV reporting with embedded, secure image URLs for external stakeholders.

---

## 🛠️ Deployment & Setup

### 📦 Prerequisites
- **Python:** 3.11+
- **Flutter SDK:** 3.10+ (Stable Channel)
- **Database:** PostgreSQL 14+

### 🔑 Environment Configuration
Create a `.env` file in the `backend/` directory:

```env
# System Identity
SYSTEM_NAME=GoAgile
SYSTEM_CODE=GOA

# Database
DATABASE_URL=postgresql://user:pass@localhost/assetdb
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=10

# Security
JWT_SECRET=your-32-character-minimal-secret
JWT_ALGORITHM=HS256

# Outgoing Mail (SMTP)
MAIL_HOST=smtp.your-provider.com
MAIL_PORT=465
MAIL_USERNAME=no-reply@domain.com
MAIL_PASSWORD=secure-pass
MAIL_ENCRYPTION=ssl
MAIL_FROM_ADDRESS=no-reply@domain.com
MAIL_FROM_NAME="Asset Management"

# Incoming Support (IMAP)
IMAP_HOST=imap.your-provider.com
IMAP_PORT=993
IMAP_USERNAME=support@domain.com
IMAP_PASSWORD=secure-pass
```

### 🚀 Launch Sequence

#### 1. Backend Initialization
```bash
cd backend
pip install -r requirements.txt
# Optional: Setup SuperAdmin if database is empty
# python make_superadmin.py 
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 &
```

#### 2. Frontend Deployment
```bash
cd frontend
flutter pub get
flutter build web --release
# Serve the artifacts
cd build/web
python3 -m http.server 8080 &
```

---

## 👨‍💻 Developer Maintenance

### Adding New Fields
New base fields should be added to `app/models/asset.py` and subsequently registered in the `seed_mvp_data` function in `app/bootstrap.py` to ensure consistency across tenants.

### Security Audits
All endpoints are guarded by the `require_permission` dependency. New features must explicitly define required permission keys in the `DEFAULT_PERMISSIONS` constant within `app/schemas/admin.py`.

---
© 2026 **GoAgile Technologies**. This platform is a production-grade asset management solution. Proprietary and Confidential.
