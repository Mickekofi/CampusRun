# Single Source of Truth

- It serves as the single source of truth for all frontend-to-backend communication, routing, and data persistence.

1. Frontend say `frontend/lib/Users/signupscreen.dart` sends a POST request

```dart
final response = await http.post(
  Uri.parse("http://192.168.1.5:5000/api/signup"),
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({
    "name": name,
    "email": email,
    "password": password,    
  }),
);

final data = jsonDecode(response.body);
```

directly pointing to The Right Address:  
The right address is made up off two parts:

1. Server's own address IP address (with a port included),eg: `http://192.168.1.100:5000`

In addition to(+)

2. the resource address(creating endpoint address(look at step 5 for reference)) which is directly assigned to One Specified route address

In total(1+2) you get; eg: `http://192.168.1.100:5000/api/signuproutes`

---

2) If Address and Resource exits, example;

```js
// a). Importing and assigning the available routes resources living in the routes folder.
//=================================================================
const signupRoutes = require('./routes/Users/signupRoutes');
```

and

```js
// b). We then create address(endpoints) for each of the imported resources(routes),
app.use('/api/signuproutes', signupRoutes);
```

It routes to the `backend/Users/routes` directory say a file called `backend/Users/routes/signupRoutes.js`

---

3. `backend/Users/routes/signupRoutes.js` (A file Responsible for routing) also Sends out the response the `backend/Users/controllers` lets say a file called `backend/controller/signupController.js`

---

3. `backend/Users/controller/signupController.js`  
( A file responsible for validations,database logics, business strategy logics at the backend side) also sends it reponse to the database in the `backend/config` say a file called `db.js`, and Back to the Frontend.

---

# The Folder Structure

The CampusRun repository is organized into logical modules that separate concerns and enable independent deployment and scaling.

## Backend Structure (`backend/`)

```
backend/
├── server.js                          # Express server entry point
├── package.json                       # Node.js dependencies
├── .env.example                       # Environment template
│
├── config/
│   └── db.js                          # MySQL connection pool & initialization
│
├── routes/
│   ├── login_routes.js                # Authentication endpoints
│   ├── googleRoutes.js                # Google OAuth
│   ├── Users/
│   │   ├── signupRoutes.js            # User signup flow
│   │   ├── phoneRoutes.js             # Phone verification
│   │   ├── user_password_routes.js    # Password reset
│   │   ├── user_dashboard_routes.js   # Dashboard data
│   │   ├── user_bikeSelection_routes.js  # Bike browsing
│   │   ├── user_confirm_bike_routes.js   # Bike confirmation
│   │   ├── user_payment_routes.js     # Payment processing
│   │   ├── user_deposit_screen_routes.js # Wallet top-up
│   │   ├── user_scanQR_routes.js      # QR code scanning
│   │   ├── user_ridemode_routes.js    # Active ride data
│   │   └── user_account_routes.js     # Profile management
│   │
│   └── Administrator/
│       ├── admin_bike_upload_routes.js    # Bike fleet management
│       ├── admin_station_upload_routes.js # Station management
│       ├── admin_bike_operations_routes.js # Bike status & maintenance
│       ├── admin_user_monitor_routes.js   # User tracking
│       └── admin_live_tracker_routes.js   # Real-time GPS & metrics
│
├── controllers/
│   ├── login_role_access_controller.js    # Authentication logic
│   ├── google_controller.js               # Google OAuth handlers
│   │
│   ├── Users/
│   │   ├── signupController.js            # Signup business logic
│   │   ├── phone_controller.js            # Phone OTP logic
│   │   ├── user_account_controller.js     # Profile operations
│   │   ├── user_bikeSelection_controller.js
│   │   └── ... (other user controllers)
│   │
│   └── Administrator/
│       ├── admin_bike_operations_controller.js
│       ├── admin_bike_upload_controller.js
│       ├── admin_live_tracker_controller.js
│       ├── admin_station_upload_controller.js
│       └── admin_user_monitor_controller.js
│
├── testings/
│   └── encryption_gen.js              # Utility for testing encryption
│
└── uploads/
    └── bikes/                         # Bike image storage
```

## Frontend Structure (`frontend/`)

```
frontend/
├── lib/
│   ├── main.dart                      # App entry point & theme setup
│   ├── firebase_options.dart          # Firebase configuration
│   ├── theme_settings.dart            # Global theme (60:30:10 rule)
│   ├── admin_ip.dart                  # Backend URL configuration
│   ├── login_screen.dart              # Authentication UI
│   ├── user_password_screen.dart      # Password reset UI
│   ├── session_screen.dart            # Session management
│   ├── admin_dashboard_screen.dart    # Admin dashboard
│   │
│   ├── Users/
│   │   ├── user_signup_screen.dart    # Signup form
│   │   ├── phone_confirmation_screen.dart
│   │   ├── user_bike_selection_screen.dart
│   │   ├── user_confirm_bike_screen.dart
│   │   ├── user_payment_screen.dart
│   │   ├── user_ride_mode_screen.dart
│   │   ├── user_account_screen.dart
│   │   └── ... (other user screens)
│   │
│   ├── Administrator/
│   │   ├── admin_bike_upload_screen.dart
│   │   ├── admin_station_upload_screen.dart
│   │   ├── admin_live_tracker_screen.dart
│   │   ├── admin_user_monitor_screen.dart
│   │   └── admin_bike_operations_screen.dart
│   │
│   └── widgets/
│       ├── custom_button.dart         # Reusable button component
│       ├── bike_card.dart             # Bike display card
│       ├── station_marker.dart        # Map station marker
│       └── ... (other shared widgets)
│
├── android/                           # Android-specific build files
├── ios/                               # iOS-specific build files
├── web/                               # Web deployment files
├── windows/ & linux/ & macos/         # Desktop platform files
│
├── pubspec.yaml                       # Flutter dependencies
├── .env.example                       # Backend URL template
└── analysis_options.yaml              # Linting rules
```

---

# Technology Stack

## Backend Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Runtime** | Node.js (v18+) | Lightweight, non-blocking I/O for real-time features |
| **Web Framework** | Express.js | HTTP routing and middleware |
| **Database** | MySQL 8.0+ | Relational data storage with transactions |
| **Authentication** | JWT + bcrypt | Stateless session & password hashing |
| **File Upload** | Multer | Handle bike/station images |
| **CORS** | cors package | Cross-origin requests from Flutter app |
| **Environment** | dotenv | Secure config management |
| **OAuth** | Google Sign-In | Alternative authentication method |

## Frontend Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.11+ | Cross-platform iOS/Android app |
| **Language** | Dart | Flutter's native language |
| **State Management** | Provider / GetX (optional) | In-app state & reactive updates |
| **HTTP Client** | http package | API communication |
| **Authentication** | Firebase Auth + JWT | User session & token storage |
| **Maps** | flutter_map + latlong2 | Real-time GPS tracking & geofencing |
| **File Picker** | file_picker | Image/document upload |
| **Image Picker** | image_picker | Camera & gallery integration |
| **Environment** | flutter_dotenv | Backend URL configuration |
| **Design System** | Custom theme | 60:30:10 color rule |

---

# Data Flow Architecture

## Request-Response Cycle

```
┌─────────────────────────────────────────────────────────────┐
│  FRONTEND (Flutter)                                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  UI Layer (user_bike_selection_screen.dart)          │  │
│  │  - User taps "Select Bike"                           │  │
│  │  - gathers: pickup_station, bike_id                  │  │
│  └──────────────┬───────────────────────────────────────┘  │
│                 │                                           │
│                 │ http.post("/api/confirm-bike")            │
│                 ▼                                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  HTTP Layer (main.dart)                              │  │
│  │  - Adds headers: {"Content-Type": "application/json"}│  │
│  │  - Encodes body:                                     │  │
│  │    { "bike_id": 5, "station_id": 3 }                │  │
│  └──────────────┬───────────────────────────────────────┘  │
└─────────────────│─────────────────────────────────────────┘
                  │
         ═════════▼══════════ NETWORK ════════════
                  │
┌─────────────────│─────────────────────────────────────────┐
│  BACKEND (Node.js)                                        │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  server.js (Express)                                 │ │
│  │  - Matches route: /api/confirm-bike                  │ │
│  │  - Passes to: confirmBikeRoutes.js                   │ │
│  └──────────────┬───────────────────────────────────────┘ │
│                 │                                         │
│                 ▼                                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  confirmBikeRoutes.js (Router)                        │ │
│  │  - Validates JWT token                               │ │
│  │  - Extracts user_id from token                        │ │
│  │  - Calls controller                                   │ │
│  └──────────────┬───────────────────────────────────────┘ │
│                 │                                         │
│                 ▼                                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  userConfirmBikeController.js (Business Logic)        │ │
│  │  - Validate bike exists and is available              │ │
│  │  - Validate user has sufficient wallet                │ │
│  │  - Calculate estimated price                          │ │
│  │  - Create reservation record                          │ │
│  │  - Call db.query()                                    │ │
│  └──────────────┬───────────────────────────────────────┘ │
│                 │                                         │
│                 ▼                                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  config/db.js (Data Layer)                            │ │
│  │  - Execute: INSERT INTO reservations (...)            │ │
│  │  - Return result or error                             │ │
│  └──────────────┬───────────────────────────────────────┘ │
│                 │                                         │
│                 ▼                                         │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  MySQL Database                                       │ │
│  │  - Store reservation in DB                            │ │
│  │  - Return affected rows & last_insert_id              │ │
│  └──────────────┬───────────────────────────────────────┘ │
│                 │                                         │
│                 │ Response: { success: true, ... }        │
│                 ▼                                         │
│  Back through controller → router → server → HTTP 200 OK  │
└─────────────────────────────────────────────────────────┘
                  │
         ═════════▼══════════ NETWORK ════════════
                  │
┌─────────────────│─────────────────────────────────────────┐
│  FRONTEND (Flutter)                                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  HTTP Response Handler                               │ │
│  │  - Receives 200 OK                                   │ │
│  │  - Parses JSON response                              │ │
│  │  - Updates UI state (reservation_code, timer)        │ │
│  │  - Navigates to next screen                          │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

# Backend Architecture

## Route Layer

**Responsibility:** Pattern matching and HTTP method handling

Each route file maps URL paths to controller functions:

```js
// backend/routes/Users/user_confirm_bike_routes.js
const express = require('express');
const router = express.Router();
const { confirmBike } = require('../../controllers/Users/user_bikeSelection_controller');
const authMiddleware = require('../../middleware/authMiddleware'); // JWT verification

// POST /api/confirm-bike
router.post('/', authMiddleware, confirmBike);

module.exports = router;
```

**Key behaviors:**
- Validates HTTP method (GET, POST, PUT, DELETE)
- Applies middleware (authentication, validation)
- Delegates business logic to controllers

## Controller Layer

**Responsibility:** Business logic, validation, and orchestration

Controllers receive requests, apply business rules, interact with the database, and format responses:

```js
// backend/controllers/Users/user_bikeSelection_controller.js
const pool = require('../../config/db');

exports.confirmBike = async (req, res) => {
  try {
    const { bike_id, station_id } = req.body;
    const user_id = req.user.id; // From JWT middleware

    // 1. Validate inputs
    if (!bike_id || !station_id) {
      return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    // 2. Check bike availability
    const [bikeRows] = await pool.query(
      'SELECT * FROM bikes WHERE id = ? AND status = ?',
      [bike_id, 'available']
    );

    if (bikeRows.length === 0) {
      return res.status(400).json({ success: false, message: 'Bike not available' });
    }

    // 3. Check user wallet
    const [userRows] = await pool.query(
      'SELECT wallet_balance FROM users WHERE id = ?',
      [user_id]
    );

    if (userRows[0].wallet_balance < 50) { // minimum charge
      return res.status(400).json({ success: false, message: 'Insufficient wallet balance' });
    }

    // 4. Create reservation
    const reservationCode = generateCode();
    const [insertResult] = await pool.query(
      'INSERT INTO reservations (user_id, bike_id, pickup_station_id, reservation_code, expires_at, status) VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 5 MINUTE), ?)',
      [user_id, bike_id, station_id, reservationCode, 'active']
    );

    // 5. Return response
    res.status(200).json({
      success: true,
      reservation_id: insertResult.insertId,
      reservation_code: reservationCode,
      bike: bikeRows[0],
      expires_in: 300 // seconds
    });

  } catch (error) {
    console.error('Error confirming bike:', error);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};
```

**Key behaviors:**
- Input validation
- Business rule enforcement (e.g., wallet balance, bike availability)
- Database operations via connection pool
- Error handling and appropriate HTTP status codes
- Response formatting

## Data Layer

**Responsibility:** SQL query execution and connection pooling

The `config/db.js` file manages the MySQL connection pool:

```js
// backend/config/db.js
const mysql = require("mysql2/promise");

const poolOptions = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

const pool = mysql.createPool(poolOptions);

pool.getConnection((err, connection) => {
  if (err) {
    console.error("Database connection failed:", err.message);
  } else {
    console.log("Database connected successfully");
    connection.release();
  }
});

module.exports = pool;
```

**Key behaviors:**
- Connection pooling for performance
- Automatic connection reuse
- Connection timeout and queue management

---

# Frontend Architecture

## Presentation Layer (UI Screens)

Each screen is a stateful or stateless widget that renders UI and listens to user interactions:

```dart
// frontend/lib/Users/user_bike_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserBikeSelectionScreen extends StatefulWidget {
  @override
  State<UserBikeSelectionScreen> createState() => _UserBikeSelectionState();
}

class _UserBikeSelectionState extends State<UserBikeSelectionScreen> {
  List<dynamic> bikes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAvailableBikes();
  }

  Future<void> fetchAvailableBikes() async {
    try {
      final backendUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:5000';
      final response = await http.get(
        Uri.parse('$backendUrl/api/user_bikeSelection_routes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          bikes = jsonDecode(response.body)['bikes'];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void selectBike(int bikeId) async {
    // Call backend to confirm bike
    final response = await http.post(
      Uri.parse('$backendUrl/api/confirm-bike'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'bike_id': bikeId, 'station_id': selectedStationId}),
    );

    if (response.statusCode == 200) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Your Bike')),
      body: isLoading ? CircularProgressIndicator() : ListView(
        children: bikes.map((bike) => BikeCard(bike: bike, onSelect: selectBike)).toList(),
      ),
    );
  }
}
```

**Key behaviors:**
- Render UI components
- Handle user interactions
- Call HTTP endpoints
- Update local state with responses
- Navigate between screens

## Service Layer (API Communication)

Services encapsulate HTTP calls to the backend:

```dart
// frontend/lib/services/bike_service.dart

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BikeService {
  static final String baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:5000';

  static Future<List<dynamic>> fetchAvailableBikes(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user_bikeSelection_routes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['bikes'];
      } else {
        throw Exception('Failed to fetch bikes');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> confirmBike(String token, int bikeId, int stationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/confirm-bike'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bike_id': bikeId,
          'station_id': stationId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to confirm bike');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
```

**Key behaviors:**
- Centralize API communication
- Reusable across multiple screens
- Abstract HTTP details from UI layer

---

# Database Architecture

## Core Tables

| Table | Purpose | Key Fields |
| :--- | :--- | :--- |
| **users** | Student accounts & wallets | id, student_id, email, phone, password_hash, wallet_balance, account_status |
| **admins** | Administrative accounts | id, email, phone, password_hash, role (super_admin, operations_manager, etc.), account_status |
| **stations** | Pickup and dropoff locations | id, station_name, station_type, latitude, longitude, radius_meters, status |
| **bikes** | Bike fleet inventory | id, bike_code, bike_name, battery_level, gps_lat, gps_lng, status (available, reserved, active, maintenance), current_station_id |
| **reservations** | Temporary bike locks | id, user_id, bike_id, pickup_station_id, reservation_code, expires_at, status |
| **rides** | Completed ride records | id, user_id, bike_id, pickup_station_id, dropoff_station_id, start_time, end_time, distance_km, duration_minutes, fare_amount |
| **payments** | Payment transactions | id, user_id, ride_id, amount, payment_method, status (pending, success, failed) |
| **wallet_transactions** | Wallet history | id, user_id, transaction_type (deposit, ride_charge, refund), amount, balance_after |

## Entity Relationships

```
users (1) ──────→ (M) reservations ──────→ (1) bikes
 ↓                                          ↓
 └─→ (M) rides ──→ (1) stations            └─→ (1) stations
      ↓
      └─→ (M) payments
           ↓
           └─→ (1) wallet_transactions

admins (1) ──────→ (M) stations
igualmente
admins (1) ──────→ (M) bikes
```

---

# Authentication & Authorization Flow

## JWT-Based Authentication

1. **User Login**
   - Frontend sends email & password to `/api/loginroutes`
   - Backend validates credentials against `users` table
   - Backend generates JWT token with payload: `{ id, email, role }`
   - Frontend stores token in secure storage (SharedPreferences on Android)

2. **Authenticated Requests**
   - Frontend includes `Authorization: Bearer <jwt_token>` in all subsequent requests
   - Backend middleware (`authMiddleware`) verifies token signature
   - If valid, attaches `req.user = { id, email, role }` to request
   - If invalid or expired, returns 401 Unauthorized

3. **Token Expiration**
   - JWT tokens expire after time defined in `JWT_EXPIRES_IN` (default: 30 days)
   - Frontend should refresh token before expiry or re-authenticate

## Role-Based Access Control (RBAC)

```js
// backend/middleware/authMiddleware.js

const jwt = require('jsonwebtoken');

exports.authMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, message: 'No token provided' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

exports.adminOnly = (req, res, next) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: 'Forbidden: Admin access required' });
  }
  next();
};
```

---

# API Endpoint Categories

## User Authentication

| Endpoint | Method | Purpose |
| :--- | :--- | :--- |
| `/api/signuproutes` | POST | Register new student account |
| `/api/loginroutes` | POST | Authenticate and get JWT token |
| `/api/phoneroutes` | POST | Verify phone number via OTP |
| `/api/userpasswordroutes` | POST | Reset forgotten password |
| `/api/googleroutes` | POST | Google OAuth sign-in |

## User Operations

| Endpoint | Method | Purpose |
| :--- | :--- | :--- |
| `/api/user_dashboard_routes` | GET | Fetch dashboard data (balance, recent rides) |
| `/api/user_bikeSelection_routes` | GET | List available bikes at nearby stations |
| `/api/confirm-bike` | POST | Reserve bike for immediate ride |
| `/api/payment` | POST | Process payment for ride |
| `/api/deposit` | POST | Add funds to wallet |
| `/api/scan` | POST | Validate QR code on bike |
| `/api/ridemode` | GET/POST | Retrieve live ride data or end ride |
| `/api/account` | GET/PUT | View or update user profile |

## Administrator Operations

| Endpoint | Method | Purpose |
| :--- | :--- | :--- |
| `/api/admin_bike_upload_routes` | POST | Add new bikes to fleet |
| `/api/admin_station_upload_routes` | POST | Create or update stations |
| `/api/admin_bike_operations_routes` | PUT | Change bike status (maintenance, inactive, etc.) |
| `/api/admin_user_monitor_routes` | GET | Monitor user accounts and violations |
| `/api/admin_live_tracker_routes` | GET | Real-time bike GPS and metrics |

---

# Error Handling Strategy

## HTTP Status Codes

| Code | Scenario | Example |
| :--- | :--- | :--- |
| **200** | Success | Bike reserved successfully |
| **201** | Resource created | New user account registered |
| **400** | Bad request | Missing bike_id in request body |
| **401** | Unauthorized | JWT token missing or invalid |
| **403** | Forbidden | User trying to access admin endpoint |
| **404** | Not found | Requested bike does not exist |
| **500** | Server error | Unexpected database failure |

## Response Format

All API responses follow a consistent JSON structure:

```json
{
  "success": true/false,
  "message": "Human-readable status message",
  "data": { /* optional: response payload */ }
}
```

**Example responses:**

Success:
```json
{
  "success": true,
  "message": "Bike selected successfully",
  "data": {
    "reservation_id": 42,
    "bike": { "id": 5, "name": "Bike #5", "battery": 95 },
    "expires_in": 300
  }
}
```

Error:
```json
{
  "success": false,
  "message": "Insufficient wallet balance. Current: GHS 5.00. Required: GHS 50.00",
  "data": null
}
```

---

# Real-Time Features

## GPS Tracking & Geofencing

- **Bike GPS:** IoT device on each bike sends location every 30 seconds to backend
- **Geofencing:** Backend checks if bike is within `radius_meters` of approved stations
- **Alert System:** If bike leaves geofence, notify admin and potentially lock bike remotely

## Live Ride Monitoring

- **Frontend polling:** Flutter app polls `/api/ridemode` every 5 seconds during active ride
- **Backend updates:** Controller queries bike GPS from IoT system and returns current location, ETA, battery
- **Visual feedback:** Map updates in real-time on user's screen

---

# Deployment Architecture

## Backend Deployment

**Development:**
- Run locally on `localhost:5000`
- Use `.env` file for local config

**Production:**
- Deploy to cloud server (AWS EC2, DigitalOcean, or Heroku)
- Use environment variables for secrets (no `.env` file pushed to production)
- Run behind reverse proxy (Nginx) for SSL/TLS
- Use PM2 for process management and auto-restart
- Set up MySQL cluster for redundancy

## Frontend Deployment

**Development:**
- Run via `flutter run` on emulator or device
- Target backend on LAN IP (e.g., `http://192.168.1.5:5000`)

**Production:**
- Build APK for Android: `flutter build apk --release`
- Build IPA for iOS: `flutter build ios --release`
- Upload to Google Play Store and Apple App Store
- Auto-update mechanism via app store versions

---

# Performance & Scalability Considerations

## Backend Optimization

- **Connection pooling:** MySQL pool maintains 10 connections (adjust as needed)
- **Index strategy:** Indexes on `student_id`, `email`, `phone`, `status`, `bike_id` for fast queries
- **Query caching:** Frequently accessed data (bike list, station list) can be cached with Redis
- **Async processing:** Long-running tasks (bike maintenance, payment reconciliation) use job queues

## Frontend Optimization

- **Lazy loading:** Bike list loads in paginated chunks (10 bikes per page)
- **Offline caching:** Store user profile and last-known bike list locally
- **Image optimization:** Compress bike and station photos before upload
- **Battery efficiency:** Location polling only active during ride, not in background

---

# Security Best Practices

1. **Secrets Management**
   - Never commit `.env` files
   - Use environment variables for `JWT_SECRET`, `DB_PASSWORD`, etc.
   - Rotate secrets regularly

2. **Passwords**
   - Hash with bcrypt (salt rounds: 10)
   - Enforce strong password policy (12+ chars, mixed case, numbers)

3. **JWT Tokens**
   - Always include `Authorization` header
   - Use HTTPS/TLS in production to prevent token interception
   - Set appropriate expiration times

4. **Input Validation**
   - Validate all incoming request data (bike_id, station_id, etc.)
   - Sanitize user input to prevent SQL injection

5. **Rate Limiting**
   - Implement rate limiting on login endpoint to prevent brute force attacks
   - Limit API requests per user per minute

---

# Development Workflow

## Local Setup

1. Clone repository
2. Install dependencies (backend: `npm install`, frontend: `flutter pub get`)
3. Create `.env` files from `.env.example` templates
4. Set up local MySQL database with `Plans/campusrun.sql`
5. Start backend: `npm start`
6. Start frontend: `flutter run`

## Code Organization

- **Feature branches:** One feature per git branch (e.g., `feature/bike-selection`)
- **Commit messages:** Use conventional commits (e.g., `feat: add bike confirmation endpoint`)
- **Code review:** All PRs reviewed before merge to main

## Testing

- **Backend:** Unit tests for controllers and database queries (Jest or Mocha)
- **Frontend:** Widget tests for UI components, integration tests for API flows
- **Manual QA:** Test signup, bike selection, payment, and ride flows on real devices

---

# Roadmap & Future Enhancements

## Phase 2 (Post-MVP)

- Real-time notifications (push notifications for ride updates)
- In-app chat between users and support staff
- Advanced analytics dashboard for admins
- Payment integration with multiple wallets (MoMo, Vodafone Cash, credit card)
- Bike maintenance scheduling and predictive alerting

## Phase 3 (Scaling)

- Multi-campus management system
- Analytics and insights for university transportation planning
- API for third-party integrations (calendar sync, class notifications)
- Premium membership tiers and subscription options

---

This architecture enables **reliable, scalable, and maintainable development** of the CampusRun platform while keeping the codebase modular, testable, and easy to extend.
