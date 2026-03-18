# CampusRun – Full Operational Story

This document captures the end-to-end operational journey of CampusRun from registration to ride completion and bike turnover.

---

## Phase 1: Registration & Account Readiness

John, a student from North Campus, needs to get to his 8:00 AM class at South Campus.
He installs the CampusRun app.

### Registration/Login Flow
- John registers with:
  - UEW student ID
  - UEW email
- His phone number is linked to MoMo for payment operations.
- The system verifies account eligibility and activates wallet readiness.

### Outcome
John is now eligible to reserve and start rides.

---

## Phase 2: Pickup Selection & Bike Discovery

At 7:50 AM, John opens CampusRun.

### Pickup Selection
- App shows nearby approved stations.
- John selects **Student Center Block** as pickup station.

### What the app shows
- Bikes currently available at station
- Bikes moving to station with ETA countdown

John chooses **Bike #12**:
- battery: 85%
- ETA: 2 minutes

### Outcome
A concrete bike target is selected for reservation/start.

---

## Phase 3: Destination (Arrival) Selection

John chooses where he will dock.

### Option O1 — Main Approved Stations
From Student Center pickup, approved arrival docks include:
1. Faculty Block
2. Business Block
3. JAM
4. Central Campus
5. South Campus

### Option O2 — Other Locations (Optional / Non-Class)
- User can enter a custom location.
- App warns: **“Unapproved location. Extra fees may apply. Only select if necessary.”**
- System auto-flags banned or outside-campus destinations.

John chooses **Faculty Block** (approved academic docking zone).

### Outcome
Destination type is established:
- approved dock flow (distance pricing)
- or custom flow (time pricing + extra controls)

---

## Phase 4: Pricing & Payment Authorization

### Dynamic Pricing Rules
- Approved locations: fare primarily based on **distance**.
- Custom/unapproved locations: fare primarily based on **duration (per minute)**.

### User Transparency
- Estimated cost is displayed before booking.
- John confirms payment via MoMo; wallet is prepared/charged according to booking policy.

### Product Intent
- Fair and predictable pricing model
- Academic incentive for approved dock endings (discounts/caps)
- Fewer disputes around class-time vs ride-time charging

---

## Phase 5: Ride Start & Validation Gate

John reaches Student Center station and scans Bike #12 QR.

### Backend Pre-Unlock Validation
Before unlock, backend validates:
- wallet/payment readiness
- bike availability state
- GPS/location correctness
- user account status

All checks pass → bike unlocks → ride starts.

### IoT Telemetry Start
During active ride, bike streams telemetry approximately every 30 seconds:
- GPS coordinates
- battery level
- speed/lock status (as available)

### Outcome
Ride transitions from reservation/start intent to active tracked trip.

---

## Phase 6: En-Route Monitoring

John rides toward South Campus area.

### Live Ride Controls
- App displays live ETA to destination dock.
- Battery is monitored; low-battery warnings can be triggered.
- Geo-fence policy checks generate alerts if leaving allowed areas.

### Outcome
Safety, compliance, and destination predictability are maintained in real time.

---

## Phase 7: Ride End, Fare Finalization & Analytics

John arrives at Faculty Block dock, parks correctly, then taps **End Ride**.

### End-Ride Verification
System validates:
- bike is inside permitted geo-fence
- lock is engaged
- ride duration and end context are valid

### Fare Finalization
- Distance/time confirmed
- Eligible discounts/caps applied
- Over-limit penalties applied where needed
- Wallet debited automatically
- Receipt shown to John

### Admin/Operations Effects
- Bike status updated to **available**
- Ride records saved for analytics/reporting
- Bike becomes visible to next eligible student

---

## Phase 8: Reuse Cycle & Double-Booking Prevention

Another student (Esther) opens app and sees Bike #12 available.

### System guarantees
- No double-booking for same bike/time window
- Bikes in transit, low battery, or maintenance state are filtered
- Only eligible bikes/stations are shown for booking continuity

### Outcome
CampusRun maintains a continuous, safe, and auditable bike turnover cycle.

---

## Operational Architecture Intent (Why this flow works)

- **Predictable onboarding**: user readiness gates before ride eligibility.
- **Policy-backed routing**: approved vs custom destination with explicit pricing logic.
- **Validation-first unlock**: no ride begins without account, wallet, and bike checks.
- **Telemetry-backed enforcement**: geo-fence and battery intelligence during active rides.
- **Deterministic closure**: verified end-ride event before fare settlement.
- **Operational continuity**: immediate bike state update for next rider.

---

## Data Model Alignment (Current)

This story maps directly to existing core tables in the schema:
- Identity & access: `users`, `admins`, `login_audit_logs`
- Operations & assets: `stations`, `bikes`, `reservations`, `rides`, `bike_telemetry`
- Financials: `payments`, `wallet_transactions`
- Governance: `admin_logs`, `violations`

---

## Reusable Pattern for Future Apps

Use the same pattern in other projects:
1. Readiness gates before service access
2. Reservation/intent layer before active session
3. Dynamic pricing based on destination policy
4. Real-time telemetry during active session
5. Verified completion before settlement
6. Immediate asset-state update for next user
