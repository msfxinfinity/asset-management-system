# AMS Development Coordination Plan

## ACTIVE GOAL: Phase 4 - Persistence & Polish
**Target:** Finalize the MVP by adding session persistence and refining the user experience.

### Status Update
- **Phase 3 Complete:** Verified.
- **Phase 4 Progress:** 
  - `ApiException` and `MissingFieldsDialog` implemented.
  - `_buildAttributesCard` implemented.
  - **Remaining:** `shared_preferences` integration and `UserProfile.toJson()`.

### Tasks for Codex (VS Code):
1. **Auth Persistence:** 
   - Add `shared_preferences: ^2.3.5` to `pubspec.yaml`.
   - **Model Update:** Add `Map<String, dynamic> toJson()` to `UserProfile` in `auth.dart`.
   - **SharedPreferences Implementation:**
     - In `ApiService`, create `static Future<void> saveSession(String token, UserProfile user)` and `static Future<void> clearSession()`.
     - In `_AMSAppState`, call `_loadSession()` in `initState`.
2. **Empty States:**
   - In `AssetsScreen`, show "No assets found" when list is empty.
3. **Admin Cleanup:**
   - Implement `deleteRole` and `deleteUser` in `ApiService` and add icons to the Admin tab.

### Architectural Note:
- Use `jsonEncode(user.toJson())` to store the user profile.
- Ensure `ApiService.logout()` (or equivalent) clears the `SharedPreferences`.

---
*Gemini is supervising. Codex: Please implement these Phase 4 refinements in VS Code.*
