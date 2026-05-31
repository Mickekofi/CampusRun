=<p align="center">
  <a href="">
    <img src="https://github.com/Mickekofi/CampusRun/blob/main/bike_logo.png" alt="Logo" width="130">
  </a>
  <a href = "">
  <h1 align="center"><strong>CampusRun</strong></h1>
  </a>
  <p align="center">
    <a href="https://wa.me/233597326320?text=*CampusRun_From_Github_User_💬Message_:*%20">
      <img src="https://img.shields.io/badge/Engineers-red.svg" alt="Build Status">
    </a>
    <a href="https://wa.me/233505994829?text=*CampusRun_From_Github_User_💬Message_:*%20">
      <img src="https://img.shields.io/badge/Contact-Engineers-red.svg" alt="Build Status">
    </a>
  </p>
</p>


---
🆃🅷🅴 🆄🅽🅸🆅🅴🆁🆂🅸🆃🆈'🆂 🆂🅼🅰🆁🆃🅴🆂🆃 🆃🆁🅰🅽🆂🅿🅾🆁🆃

As apart of the **University Of Education, Winneba** long term innovational vision towards archiving smart Campus solutions, We Introduce **CampusRun**;  
At CampusRun We are commited to one Course: **Innovating Transport**

---

### Explain What you do to a 5-year-old
We are making transport Available, at all Campuses (North, Central, South) and, at every coner and every where and very Cheep to all students of the University.

---

### How do we deliver value

| Question | Answer |
| :--- | :--- |
| **Who are the customers?** | The University Community |
| **What value do we provide?** | Available and Cheep Smart Transport |
| **How do we deliver that value?** | Mobile app + driver network |
| **How do we earn revenue?** | Commission from each ride |

---

### Our Promise
> “CampusRun will allow all affliates smart mobility across campus in under 5 minutes instead of walking 20 minutes.”


---

### The Operational Flow: Full Story()

#### **Phase 1: Onboarding**
John, a student from North Campus, needs to get to his 8:00 AM class at South Campus. He downloads the CampusRun app.
* **Registration / Login:** John registers using his UEW student ID and email.
* **Payment Link:** His phone number is linked to MoMo for payments.
* **Verification:** System verifies John’s account, activating his wallet.

#### **Phase 2: PickUp Selection**
It’s 7:50 AM. John opens CampusRun.
* **Selecting Pickup Station:** App shows a list of nearby parking stations. John selects **Student Center Block**.
* **Station Display:** App shows available bikes, bikes incoming with ETA, and battery levels. John selects **Bike #12** (85% charged, arriving in 2 mins).

#### **Phase 3: Arrival Station**
John has two options for his destination:
1.  **Option (o1) - Main Stations:** Faculty Block, Business Block, JAM, Central Campus, South Campus.
2.  **Option (o2) - Other Locations:** Custom locations trigger a warning: *“Unapproved location. Extra fees may apply.”*

John selects **Faculty Block** to ensure he docks at a controlled academic zone.

#### **Phase 4: Pricing & Payment**
* **Dynamic Logic:** Price is calculated by distance for approved docks; price is per minute for custom locations.
* **Confirmation:** John confirms via MoMo; the wallet is charged.
* **Board Insight:** Provides academic incentives (discounts) for ending rides at approved docks.

#### **Phase 5: Ride Start**
John scans the **QR code** on Bike #12.
* **Backend Validation:** Checks wallet balance, bike availability, GPS, and account status.
* **IoT Integration:** Bike unlocks. IoT sends GPS + battery telemetry every 30 seconds.

#### **Phase 6: During the Ride**
John rides to South Campus. The app shows live ETA and monitors battery levels. Geo-fencing prevents rides outside allowed areas.

#### **Phase 7: Arrival & Ride Completion**
John arrives at the Faculty Block dock and taps **“End Ride.”**
* **System Verification:** Checks if bike is in geo-fence and lock is engaged.
* **Fare Calculation:** Final distance/time confirmed. Discounts or "Over Limit" punishments applied. Receipt displayed.

#### **Phase 8: Multiple Students & Fleet Management**
Ester arrives at the dock. She sees Bike #12 is now available. The backend prevents double-booking and filters out bikes with low battery or those needing maintenance.

#### **Phase 9: Exception Handling**
* **Battery dies:** App warns student, suggests nearest dock, notifies Admin.
* **Forgot to end ride:** System auto-ends after max duration and computes charges.
* **Tampering:** Remote lock engages; Admin investigates.
* **Unapproved ride:** System flags location and applies optional surcharge.

---

### Introducing Today; The MVP
Here are the most Important to talk about:

1. See also **[The Product Graphics Engineering Design](https://github.com/Mickekofi/CampusRun/product-graphics-engineering-design.md)**

2. See also **[The Product Engineering Architecture](https://github.com/Mickekofi/CampusRun/blob/main/product-engineering-architecture.md)**

3. See also **[The DataBase Engineering Design](https://github.com/Mickekofi/CampusRun/DataBase-engineering-design.md)**

4. See also **[Project Scope(Bugeting & Cost) and Risk Assessment](https://github.com/Mickekofi/CampusRun/project-scope-risk-assessment.md)**

5. See also **[Requirement and System Specification](https://github.com/Mickekofi/CampusRun/requirement-system-specification.md)**

6. See also **[Product StartUp and Regulation](https://github.com/Mickekofi/CampusRun/product-startup-regulation.md)**

---

### Requirements and Installation

#### Requirements

Before setting up CampusRun locally, make sure you have:

- Node.js and npm
- Flutter SDK
- MySQL server
- Git
- Android Studio, VS Code, or another Flutter-compatible editor
- An emulator, simulator, or physical device for running the app

#### Project Structure

This repository is split into two main parts:

- `backend/` for the Node.js API
- `frontend/` for the Flutter app

#### Step 1: Clone the Repository

```bash
git clone https://github.com/Mickekofi/CampusRun.git
cd CampusRun
```

#### Step 2: Set Up the Database

The backend expects a MySQL database and the connection values are read from `backend/.env`.

1. Create a MySQL database named `campusrun_db`.
2. Import the schema from `Plans/campusrun.sql` into that database.
3. Confirm your MySQL server is running.

A typical MySQL setup looks like this:

```bash
mysql -u root -p
CREATE DATABASE campusrun_db;
USE campusrun_db;
SOURCE Plans/campusrun.sql;
```

If you use MySQL Workbench or phpMyAdmin, you can import the SQL file there instead.

#### Step 3: Configure the Backend Environment

Create `backend/.env` using `backend/.env.example` as the template.

Example:

```env
NODE_ENV=development
PORT=5000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=campusrun_db
JWT_SECRET=replace_with_a_secure_secret
JWT_EXPIRES_IN=30d
```

The backend reads these values in `backend/config/db.js` and `backend/server.js`.

#### Step 4: Install Backend Dependencies

```bash
cd backend
npm install
```

This installs the Express server, MySQL client, CORS support, file upload handling, and dotenv configuration used by the API.

#### Step 5: Configure the Flutter Environment

Create `frontend/.env` using `frontend/.env.example` as the template.

Example:

```env
BACKEND_URL=http://your-backend-ip:5000
```

If you do not set `BACKEND_URL`, you can use the split values instead:

```env
BACKEND_IP=your-backend-ip
BACKEND_PORT=5000
```

The Flutter app loads this file in `frontend/lib/main.dart` and uses it in `frontend/lib/admin_ip.dart`.

#### Step 6: Install Flutter Dependencies

```bash
cd ../frontend
flutter pub get
```

This fetches the packages required by the Flutter client, including Firebase, HTTP, file picking, image picking, map support, and dotenv.

#### Step 7: Run the Backend Server

From the `backend/` folder:

```bash
npm start
```

The server starts on the port defined in `backend/.env`, or `5000` if no port is set.

#### Step 8: Run the Flutter App

From the `frontend/` folder:

```bash
flutter run
```

If you want to run on a specific device, list your devices first:

```bash
flutter devices
```

Then run with the desired target:

```bash
flutter run -d <device_id>
```

#### Step 9: Verify the Setup

Once both apps are running:

- Open the Flutter app on your device or emulator
- Confirm the app can reach the backend URL from the `.env` file
- Check the backend health endpoint if needed:

```bash
curl http://localhost:5000/api/health
```

You should receive a JSON response showing that the server is active.

#### Common Notes

- Keep `backend/.env` and `frontend/.env` out of version control
- Make sure MySQL is running before starting the backend
- If the app cannot connect, check that `BACKEND_URL`, `DB_HOST`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` are correct
- If you change environment variables, restart the backend and rerun the Flutter app
