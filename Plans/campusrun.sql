--1. This table stores:Student accounts, Authentication data, Account statusWallet balance,Identity reference, It is the root entity of the system. Everything connects to users:Rides,Payments,Wallet Transactions, Violations, Reservations
CREATE TABLE
    users (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        student_id VARCHAR(50) NOT NULL UNIQUE,
        full_name VARCHAR(150) NOT NULL,
        email VARCHAR(150) NOT NULL UNIQUE,
        profile_picture VARCHAR(255) DEFAULT NULL,
        phone VARCHAR(20) NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        wallet_balance DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        account_status ENUM ('active', 'suspended', 'banned') NOT NULL DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_student_id (student_id),
        INDEX idx_email (email),
        INDEX idx_phone (phone),
        INDEX idx_status (account_status)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- Admins will have:One-to-Many relationship with:admin_logs, bikes (who uploaded it),stations (who created it),pricing_rules,violations (if manually issued)
CREATE TABLE
    admins (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        full_name VARCHAR(150) NOT NULL,
        email VARCHAR(150) NOT NULL UNIQUE,
        phone VARCHAR(20) UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        role ENUM (
            'super_admin',
            'operations_manager',
            'finance_manager',
            'support_staff'
        ) NOT NULL DEFAULT 'support_staff',
        account_status ENUM ('active', 'suspended') NOT NULL DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_email (email),
        INDEX idx_role (role),
        INDEX idx_status (account_status)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- What This Table Does This table stores:Approved pickup station, Approved drop-off stations, GPS coordinates, Geo-fence radius, Status (active/inactive),Admin who created it
CREATE TABLE
    stations (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        station_name VARCHAR(150) NOT NULL,
        station_type ENUM ('pickup', 'dropoff', 'both') NOT NULL DEFAULT 'both',
        latitude DECIMAL(10, 8) NOT NULL,
        longitude DECIMAL(11, 8) NOT NULL,
        radius_meters INT UNSIGNED NOT NULL DEFAULT 50,
        base_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        status ENUM ('active', 'inactive') NOT NULL DEFAULT 'active',
        created_by BIGINT UNSIGNED NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (created_by) REFERENCES admins (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        INDEX idx_station_type (station_type),
        INDEX idx_status (status),
        INDEX idx_lat_lng (latitude, longitude)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- We define: available reserved, active (currently in ride, maintenance, inactive, tampered
CREATE TABLE
    bikes (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        bike_code VARCHAR(100) NOT NULL UNIQUE,
        bike_name VARCHAR(150) NOT NULL,
        bike_image VARCHAR(255) NULL,
        battery_level TINYINT UNSIGNED NOT NULL DEFAULT 100,
        gps_lat DECIMAL(10, 8) NULL,
        gps_lng DECIMAL(11, 8) NULL,

        speed_kmh DECIMAL(5,2) NULL AFTER gps_lng,
        heading DECIMAL(5,2) NULL AFTER speed_kmh;
        status ENUM (
            'available',
            'reserved',
            'active',
            'maintenance',
            'inactive',
            'tampered'
        ) NOT NULL DEFAULT 'inactive',
        current_station_id BIGINT UNSIGNED NULL,
        total_rides INT UNSIGNED NOT NULL DEFAULT 0,
        last_service_date DATE NULL,
        created_by BIGINT UNSIGNED NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (current_station_id) REFERENCES stations (id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY (created_by) REFERENCES admins (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        INDEX idx_status (status),
        INDEX idx_station (current_station_id),
        INDEX idx_battery (battery_level)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- What This Table Does: This table temporarily locks a bike for a user before ride starts. Flow:User selects bike. System creates reservation.,Reservation expires after X minutes. If user unlocks → reservation becomes ride. If not → reservation auto expires. This protects availability integrity.
CREATE TABLE
    reservations (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        user_id BIGINT UNSIGNED NOT NULL,
        bike_id BIGINT UNSIGNED NOT NULL,
        pickup_station_id BIGINT UNSIGNED NOT NULL,
        reservation_code VARCHAR(100) NOT NULL UNIQUE,
        expires_at DATETIME NOT NULL,
        status ENUM ('active', 'expired', 'converted', 'cancelled') NOT NULL DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (bike_id) REFERENCES bikes (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (pickup_station_id) REFERENCES stations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        INDEX idx_user (user_id),
        INDEX idx_bike (bike_id),
        INDEX idx_status (status),
        INDEX idx_expires (expires_at)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- This table records every actual ride. Lifecycle: Reservation converted to ride, Bike unlocked, Ride becomes active, GPS tracking ongoing, Ride ends at approved station, Fare calculated, Payment processed,This table stores permanent ride history.
CREATE TABLE
    rides (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        ride_code VARCHAR(100) NOT NULL UNIQUE,
        user_id BIGINT UNSIGNED NOT NULL,
        bike_id BIGINT UNSIGNED NOT NULL,
        reservation_id BIGINT UNSIGNED NULL,
        pickup_station_id BIGINT UNSIGNED NOT NULL,
        drop_station_id BIGINT UNSIGNED NULL,
        start_time DATETIME NOT NULL,
        end_time DATETIME NULL,
        duration_minutes INT UNSIGNED NULL,
        distance_km DECIMAL(10, 2) NULL,
        base_fare DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        time_fare DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        distance_fare DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        penalty_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        total_fare DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        allocated_time INT UNSIGNED NULL,
        ride_status ENUM ('active', 'completed', 'cancelled') NOT NULL DEFAULT 'active',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (bike_id) REFERENCES bikes (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (reservation_id) REFERENCES reservations (id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY (pickup_station_id) REFERENCES stations (id) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (drop_station_id) REFERENCES stations (id) ON DELETE SET NULL ON UPDATE CASCADE,
        INDEX idx_user (user_id),
        INDEX idx_bike (bike_id),
        INDEX idx_status (ride_status),
        INDEX idx_start_time (start_time)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- This table stores:• Every financial transaction • Wallet deduction • MoMo payment • Refund • Failed attempt
    CREATE TABLE
        payments (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            payment_reference VARCHAR(120) NOT NULL UNIQUE,
            user_id BIGINT UNSIGNED NOT NULL,
            ride_id BIGINT UNSIGNED NULL,
            amount DECIMAL(10, 2) NOT NULL,
            payment_method ENUM ('wallet', 'momo', 'card') NOT NULL,
            payment_provider ENUM('MTN', 'Telecel', 'AirtelTigo', 'Paystack', 'Hubtel', 'Internal') NULL,
            transaction_type ENUM (
                'ride_payment',
                'wallet_topup',
                'refund',
                'penalty'
            ) NOT NULL,
            payment_status ENUM ('pending', 'successful', 'failed') NOT NULL DEFAULT 'pending',
            external_reference VARCHAR(150) NULL,
            processed_by BIGINT UNSIGNED NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
            FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE SET NULL ON UPDATE CASCADE,
            FOREIGN KEY (processed_by) REFERENCES admins (id) ON DELETE SET NULL ON UPDATE CASCADE,
            INDEX idx_user (user_id),
            INDEX idx_ride (ride_id),
            INDEX idx_status (payment_status),
            INDEX idx_type (transaction_type)
        ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

    -- This table records: • Every wallet top-up • Every ride deduction • Every penalty deduction • Every refund • Every manual adjustment It forms a full financial audit trail per user.
    CREATE TABLE
        wallet_transactions (
            id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
            transaction_reference VARCHAR(120) NOT NULL UNIQUE,
            user_id BIGINT UNSIGNED NOT NULL,
            payment_id BIGINT UNSIGNED NULL,
            ride_id BIGINT UNSIGNED NULL,
            transaction_type ENUM (
                'topup',
                'debit',
                'refund',
                'penalty',
                'adjustment'
            ) NOT NULL,
            amount DECIMAL(10, 2) NOT NULL,
            balance_before DECIMAL(10, 2) NOT NULL,
            balance_after DECIMAL(10, 2) NOT NULL,
            processed_by BIGINT UNSIGNED NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
            FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL ON UPDATE CASCADE,
            FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE SET NULL ON UPDATE CASCADE,
            FOREIGN KEY (processed_by) REFERENCES admins (id) ON DELETE SET NULL ON UPDATE CASCADE,
            INDEX idx_user (user_id),
            INDEX idx_type (transaction_type),
            INDEX idx_created (created_at)
        ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- This table stores: • Real-time GPS updates • Battery levels • Speed • Lock status • Movement tracking • Anti-theft monitoring
-- This is NOT transactional money data.
CREATE TABLE
    bike_telemetry (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        bike_id BIGINT UNSIGNED NOT NULL,
        ride_id BIGINT UNSIGNED NULL,
        gps_lat DECIMAL(10, 8) NOT NULL,
        gps_lng DECIMAL(11, 8) NOT NULL,
        battery_level TINYINT UNSIGNED NOT NULL,
        speed_kmh DECIMAL(5, 2) NULL,
        lock_status ENUM ('locked', 'unlocked') NOT NULL,
        signal_strength TINYINT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (bike_id) REFERENCES bikes (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE SET NULL ON UPDATE CASCADE,
        INDEX idx_bike (bike_id),
        INDEX idx_ride (ride_id),
        INDEX idx_created (created_at)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- This table records: • Every sensitive admin action • Bike uploads • Bike deletions • Station creation • Price updates • Manual wallet adjustments • Account suspensions • Ride cancellations • Penalty overrides It creates internal accountability.
CREATE TABLE
    admin_logs (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        admin_id BIGINT UNSIGNED NOT NULL,
        action_type VARCHAR(100) NOT NULL,
        target_table VARCHAR(100) NOT NULL,
        target_id BIGINT UNSIGNED NULL,
        description TEXT NOT NULL,
        ip_address VARCHAR(45) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (admin_id) REFERENCES admins (id) ON DELETE CASCADE ON UPDATE CASCADE,
        INDEX idx_admin (admin_id),
        INDEX idx_action (action_type),
        INDEX idx_created (created_at)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- This table records: • Out-of-zone riding • Bike damage reports • Late returns • Tampering attempts • Policy violations • Penalty enforcement It is your behavior enforcement + penalty engine.
CREATE TABLE
    violations (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        violation_code VARCHAR(120) NOT NULL UNIQUE,
        user_id BIGINT UNSIGNED NOT NULL,
        bike_id BIGINT UNSIGNED NOT NULL,
        ride_id BIGINT UNSIGNED NULL,
        violation_type VARCHAR(100) NOT NULL,
        penalty_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
        description TEXT NOT NULL,
        status ENUM ('pending', 'paid', 'waived') NOT NULL DEFAULT 'pending',
        issued_by BIGINT UNSIGNED NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (bike_id) REFERENCES bikes (id) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE SET NULL ON UPDATE CASCADE,
        FOREIGN KEY (issued_by) REFERENCES admins (id) ON DELETE SET NULL ON UPDATE CASCADE,
        INDEX idx_user (user_id),
        INDEX idx_status (status),
        INDEX idx_type (violation_type)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- This table records all login attempts (admin/user), including success/failure, source IP, and device user-agent.
CREATE TABLE
    login_audit_logs (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        login_reference VARCHAR(120) NOT NULL UNIQUE,
        actor_type ENUM ('admin', 'user', 'unknown') NOT NULL DEFAULT 'unknown',
        actor_id BIGINT UNSIGNED NULL,
        identifier VARCHAR(150) NOT NULL,
        login_status ENUM ('successful', 'failed') NOT NULL,
        failure_reason VARCHAR(255) NULL,
        ip_address VARCHAR(45) NULL,
        user_agent VARCHAR(255) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_actor_type (actor_type),
        INDEX idx_actor_id (actor_id),
        INDEX idx_identifier (identifier),
        INDEX idx_status (login_status),
        INDEX idx_created_at (created_at)
    ) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;