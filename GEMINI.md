# Backend-First AMS MVP Expansion Plan (with Frontend Git Tracking)

## Summary
Build this in backend-first order, then wire frontend to stable contracts.  
First Git action will add `/Users/shayanfahimi/projects/work/asset-management-system/frontend` to tracking (as requested), then implementation will prioritize backend capabilities: admin-managed custom roles, per-department customizable required fields, bulk QR generation with PDF+ZIP export, secure QR token resolution, UNASSIGNED asset lifecycle, and geolocation-to-Google-Maps support.

## Scope and Success Criteria
1. Backend supports all new admin/worker workflows without frontend mocks.
2. Admin can manage user types (custom roles with permission toggles), users, department templates, and QR batch generation.
3. Worker can scan QR and edit only permitted fields.
4. QR export supports both print-ready PDF and ZIP images.
5. Assets generated in bulk start as `UNASSIGNED`; required fields enforce transition to `ACTIVE`.
6. Frontend reflects role-based navigation with a dedicated Admin tab for admins only.
7. `frontend/` is tracked in root Git, excluding generated artifacts via existing ignore rules.

## Public API / Interface Changes
1. Auth endpoints in `/Users/shayanfahimi/projects/work/asset-management-system/backend/app/routers/auth.py`:
- `POST /auth/login`
- `POST /auth/forgot-password`
- `GET /auth/me`
2. Admin role/user management:
- `GET /admin/roles`
- `POST /admin/roles`
- `PATCH /admin/roles/{role_id}`
- `DELETE /admin/roles/{role_id}`
- `GET /admin/users`
- `POST /admin/users`
- `PATCH /admin/users/{user_id}`
- `POST /admin/users/{user_id}/reset-password`
3. Department field templates:
- `GET /admin/departments`
- `POST /admin/departments`
- `GET /admin/departments/{department_id}/fields`
- `PUT /admin/departments/{department_id}/fields`
4. QR batch generation and export:
- `POST /admin/qr-batches` with `quantity`, `department_id`, `export_formats=["pdf","zip"]`
- `GET /admin/qr-batches/{batch_id}`
- `GET /admin/qr-batches/{batch_id}/download?format=pdf|zip`
5. Asset APIs:
- `GET /assets`
- `POST /assets`
- `PATCH /assets/{asset_id}`
- `POST /assets/{asset_id}/activate`
- `PATCH /assets/{asset_id}/archive`
- `GET /assets/{asset_id}`
- `GET /assets/{asset_id}/events`
- `GET /assets/by-qr/{token}`
- `GET /assets/stats`

## Data Model and Rules
1. Keep secure public QR token separate from serial:
- `asset_token`: random immutable secure token (UUID/crypto string).
- `serial_number`: human-readable per-tenant sequence like `AMS-TENANT-000001`.
2. Add `UNASSIGNED` status to asset lifecycle in `/Users/shayanfahimi/projects/work/asset-management-system/backend/app/models/asset.py`.
3. Add role and user entities:
- `role_types` table with name + permission toggles JSON.
- `users` table linked to tenant and role type.
4. Add department template entities:
- `departments` table.
- `department_field_definitions` table with `field_key`, `label`, `type`, `required`, `visible_when_blank`, `editable_by_roles`.
5. Keep flexible field values in asset `attributes` JSONB and validate against department template.
6. Geolocation storage:
- store `location_text`, `latitude`, `longitude`.
- return computed `maps_url` for direct Google Maps open.
7. Validation logic:
- bulk-created assets have serial/token only and start `UNASSIGNED`.
- required fields are enforced on activation.
- workers can edit only fields allowed by role template.
- archived assets are read-only.
- every state/data change writes immutable asset event.

## Implementation Phases
1. Phase 0: Git tracking and cleanup.
- Add `/Users/shayanfahimi/projects/work/asset-management-system/frontend` to root Git tracking.
- Ensure generated folders remain untracked via `/Users/shayanfahimi/projects/work/asset-management-system/frontend/.gitignore`.
- Add `.DS_Store` ignore in `/Users/shayanfahimi/projects/work/asset-management-system/.gitignore`.
2. Phase 1: Backend schema and service foundation.
- Introduce new models/schemas/routers under `/Users/shayanfahimi/projects/work/asset-management-system/backend/app`.
- Normalize existing asset/event models and router contracts.
- Add tenant-seeded startup guard for local development.
3. Phase 2: QR and export pipeline.
- Generate secure token + per-tenant serial sequence atomically.
- Generate QR images from token.
- Build export service for PDF labels and ZIP image bundle.
4. Phase 3: Frontend integration.
- Rework app shell in `/Users/shayanfahimi/projects/work/asset-management-system/frontend/lib/main.dart`.
- Keep user flow: Landing -> Login -> Home -> Assets -> Scan -> Profile.
- Add dedicated Admin tab visible only for admin role.
- Hide blank fields in worker asset detail; show editable required fields in edit form.
- Geolocation click opens `maps_url`.
5. Phase 4: Deployment hardening.
- Environment-based API URL for web/iOS/android using `--dart-define`.
- CORS allowlist config from env in backend.
- Build and smoke test web, iOS, android.

## Testing and Validation
1. Backend tests.
- role/user CRUD authorization checks.
- department template validation for required fields.
- bulk generation creates correct quantity with unique token and serial sequence.
- QR by token resolves correct asset and tenant constraints.
- activation blocked until required fields set.
- archive immutability enforced.
- event log created for all state changes.
2. Frontend tests.
- role-based tab visibility.
- scan success/failure/manual entry.
- admin batch generation and download action wiring.
- hidden blank fields for workers.
- map launch URL generated correctly.
3. End-to-end smoke.
- admin creates field template and user type.
- admin generates batch QR (PDF+ZIP).
- worker scans token, fills required fields, activates asset.
- asset appears in active list and history reflects actions.

## Explicit Assumptions and Defaults
1. Backend-first delivery is mandatory for stability.
2. Dedicated Admin tab is the admin control surface.
3. Custom role types use permission presets with toggles, not full endpoint-level matrix.
4. Bulk-created assets begin in `UNASSIGNED`.
5. QR security is provided by `asset_token`; serial is operational and non-secret.
6. Both PDF and ZIP exports are required in MVP.
7. Geolocation stores both text and coordinates and exposes a Google Maps link.
