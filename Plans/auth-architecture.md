# CampusRun User/Admin Management Architecture

## 1) Core Idea
Use a **state-driven authentication architecture** where:
- The **backend is the source of truth** for auth decisions.
- The frontend handles **UI + input + navigation** only.
- Navigation is controlled by a backend contract field (`next_step`).

This keeps business rules centralized, reduces duplicated logic, and makes flows reusable across projects.

---

## 2) Purpose of This Architecture
- Support both **admin** and **user** access in one coherent system.
- Support mixed identity methods: **manual login** and **Google sign-in**.
- Enforce account readiness checks before access:
  - account status
  - password readiness
  - phone verification
- Add production-grade controls:
  - login auditing
  - brute-force lockout
  - role-based routing

---

## 3) High-Level Layers

### A. Presentation Layer (Flutter)
Responsible for:
- collecting credentials
- showing loaders/messages
- invoking backend endpoints
- routing to next screen based on backend response

Main files:
- `frontend/lib/session_screen.dart`
- `frontend/lib/login_screen.dart`
- `frontend/lib/signup_screen.dart`
- `frontend/lib/phone_validition_screen.dart`
- `frontend/lib/user_password_screen.dart`

### B. Session State Layer (Flutter)
Responsible for:
- storing role/profile/auth state in-memory during app runtime
- exposing helper flags for UI decisions

Main file:
- `frontend/lib/log_session.dart`

### C. Application/Auth Orchestration Layer (Node/Express)
Responsible for:
- role-aware authentication
- account checks
- lockout policy checks
- audit logging
- returning consistent response contracts

Main files:
- `backend/controllers/login_role_access.js`
- `backend/controllers/google.js`
- `backend/controllers/phone.js`
- `backend/controllers/user_password.js`

### D. Persistence Layer (MySQL)
Responsible for:
- identity and profile storage
- account status and password hashes
- immutable login audit trails

Schema source:
- `Plans/campusrun.sql`

---

## 4) Contract-First Auth Response
A key design decision is a route contract that returns:
- `success`
- `message`
- `role`
- `next_step`
- `data`

### `next_step` values
- `dashboard` → user/admin can proceed
- `validate_phone` → user must pass phone verification first
- `set_password` → user must establish password before manual login path

This creates deterministic routing with minimal frontend branching.

---

## 5) User Flow (Current)

## Entry Paths
1. **Session screen** offers:
   - Sign Up
   - Login
   - Continue with Google

2. **Manual Login path**:
   - Frontend posts credentials to login endpoint.
   - Backend validates identity and policy checks.
   - Backend returns role + `next_step`.
   - Frontend routes accordingly.

3. **Google path**:
   - Firebase Google auth succeeds.
   - Frontend posts profile payload to backend.
   - Backend returns account state flags.
   - Frontend routes to:
     - password setup (if required)
     - phone validation (if required)
     - dashboard (if complete)

## User Readiness Gates
A user may be blocked from dashboard until these are satisfied:
- account is active
- password is set (for Google-linked accounts needing manual login readiness)
- phone is verified (non-temporary, valid format)

## Completion Path
When all checks pass:
- session is stored in `LogSession`
- user lands on `UserDashboardPage`

---

## 6) Admin Flow (Current)
1. Admin submits identifier + password.
2. Backend checks:
   - admin record exists
   - account is active
   - password hash comparison succeeds
3. Backend writes audit log.
4. Backend returns `role: admin`, `next_step: dashboard`.
5. Frontend routes to `AdminDashboardPage`.

---

## 7) Security & Reliability Controls

### Login Audit Trail
Every attempt can be recorded with:
- actor type (`admin`, `user`, `unknown`)
- actor id when available
- identifier
- status (`successful` / `failed`)
- failure reason
- IP address
- user-agent
- reference id and timestamp

Table:
- `login_audit_logs`

### Brute-Force Lockout
Lockout policy in backend uses env-configurable values:
- max failed attempts
- attempt window
- lockout duration

If threshold exceeded:
- login is denied with retry time
- denial event is audited

### Password Hash Integrity
Manual login requires a valid bcrypt hash format before compare.
If missing/invalid hash:
- response guides account to password setup path

### Phone Validation Gate
Phone is considered unverified when:
- empty
- placeholder style (e.g., `TMP...`)
- invalid format

Unverified users are routed to phone verification before dashboard.

---

## 8) Why This Pattern Scales
- **Single source of truth**: all auth decisions in backend.
- **Thin frontend**: easier to maintain and redesign.
- **Contract-driven navigation**: fewer route bugs.
- **Auditable security posture**: supports incident analysis and compliance needs.
- **Modular growth path**: easy to add MFA, KYC, subscription checks, or organization roles as extra `next_step` states.

---

## 9) Reusable Blueprint for Future Projects
When reusing this design:
1. Define auth response contract first (`next_step` model).
2. Keep UI screens stateless about business rules.
3. Centralize account policy checks in one auth orchestrator.
4. Add immutable audit logging from day one.
5. Treat onboarding as staged gates (password, phone, profile, etc.).
6. Keep role handling unified in one login entry where possible.

---

## 10) Suggested Future Enhancements (Optional)
- Move all auth controllers behind a dedicated service layer (`AuthService`).
- Add refresh tokens and server-side session invalidation.
- Normalize response schema across all auth endpoints (`session`, `login`, `google`, `phone`, `set-password`).
- Add integration tests for each `next_step` branch.
- Add metrics dashboard for lockouts, failures, and conversion through onboarding gates.
