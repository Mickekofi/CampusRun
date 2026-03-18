const pool = require('../../config/db');

// Database initialization
const ensureSelectionTable = async () => {
  const db = pool.promise();
  await db.query(`
    CREATE TABLE IF NOT EXISTS user_bike_selections (
      id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id BIGINT UNSIGNED NOT NULL,
      bike_id BIGINT UNSIGNED NOT NULL,
      pickup_station_id BIGINT UNSIGNED NULL,
      dropoff_station_id BIGINT UNSIGNED NULL,
      use_custom_dropoff TINYINT(1) NOT NULL DEFAULT 0,
      arrival_note TEXT NULL,
      status ENUM('selected', 'confirmed', 'discarded') NOT NULL DEFAULT 'selected',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uniq_user_active_selection (user_id),
      INDEX idx_bike (bike_id),
      INDEX idx_pickup_station (pickup_station_id),
      INDEX idx_dropoff_station (dropoff_station_id),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (bike_id) REFERENCES bikes(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (pickup_station_id) REFERENCES stations(id) ON DELETE SET NULL ON UPDATE CASCADE,
      FOREIGN KEY (dropoff_station_id) REFERENCES stations(id) ON DELETE SET NULL ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);

  const [pickupColumn] = await db.query(
    `SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE()
       AND TABLE_NAME = 'user_bike_selections'
       AND COLUMN_NAME = 'pickup_station_id'
     LIMIT 1`
  );

  if (pickupColumn.length === 0) {
    await db.query(
      `ALTER TABLE user_bike_selections
       ADD COLUMN pickup_station_id BIGINT UNSIGNED NULL AFTER bike_id,
       ADD COLUMN dropoff_station_id BIGINT UNSIGNED NULL AFTER pickup_station_id,
       ADD COLUMN use_custom_dropoff TINYINT(1) NOT NULL DEFAULT 0 AFTER dropoff_station_id,
       ADD COLUMN arrival_note TEXT NULL AFTER use_custom_dropoff`
    );
  }
};

ensureSelectionTable().catch((error) => {
  console.error('user_bike_selections table setup error:', error.message);
});

// Parsers
const parseUserId = (value) => {
  const id = Number.parseInt(value, 10);
  return Number.isFinite(id) && id > 0 ? id : null;
};

const parseBikeId = (value) => {
  const id = Number.parseInt(value, 10);
  return Number.isFinite(id) && id > 0 ? id : null;
};

const parseStationId = (value) => {
  if (value === undefined || value === null || String(value).trim() == '') {
    return null;
  }
  const id = Number.parseInt(String(value), 10);
  return Number.isFinite(id) && id > 0 ? id : null;
};

// Controllers
const listPickupStations = async (_req, res) => {
  try {
    const db = pool.promise();

    const [rows] = await db.query(
      `SELECT id, station_name, station_type
       FROM stations
       WHERE status = 'active'
         AND station_type IN ('pickup', 'both')
       ORDER BY station_name ASC`
    );

    return res.status(200).json({
      success: true,
      stations: rows,
    });
  } catch (error) {
    console.error('listPickupStations error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load pickup stations.',
    });
  }
};

const listBookableBikes = async (req, res) => {
  try {
    const db = pool.promise();
    const pickupStationId = parseStationId(req.query.pickup_station_id);
    const filters = [`b.status IN ('available', 'active')`, `s.status = 'active'`, `s.station_type IN ('pickup', 'both')`];
    const params = [];

    if (pickupStationId) {
      filters.push('b.current_station_id = ?');
      params.push(pickupStationId);
    }

    const [rows] = await db.query(
      `SELECT
         b.id,
         b.bike_code,
         b.bike_name,
         b.bike_image,
         b.battery_level,
         b.status,
         b.current_station_id,
         b.updated_at,
         s.id AS station_id,
         s.station_name,
         s.station_type,
         ar.start_time AS active_ride_start,
         CASE
           WHEN b.status = 'available' THEN 0
           ELSE GREATEST(
             0, 
             /* THE FIX: Pulled the hardcoded 1200 out. Replaced with dynamic allocated_time from the rides table */
             COALESCE(ar.allocated_time, 660) - TIMESTAMPDIFF(SECOND, COALESCE(ar.start_time, b.updated_at), NOW())
           )
         END AS eta_seconds
       FROM bikes b
       INNER JOIN stations s ON s.id = b.current_station_id
       LEFT JOIN rides ar
         ON ar.bike_id = b.id
        AND ar.ride_status = 'active'
       WHERE ${filters.join(' AND ')}
       ORDER BY
         CASE WHEN b.status = 'available' THEN 0 ELSE 1 END,
         b.battery_level DESC,
         b.updated_at DESC`,
      params
    );

    return res.status(200).json({
      success: true,
      total: rows.length,
      bikes: rows,
    });
  } catch (error) {
    console.error('listBookableBikes error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load bike list.',
    });
  }
};

const selectBikeForUser = async (req, res) => {
  const userId = parseUserId(req.body?.user_id);
  const bikeId = parseBikeId(req.body?.bike_id);

  if (!userId || !bikeId) {
    return res.status(400).json({
      success: false,
      message: 'Valid user_id and bike_id are required.',
    });
  }

  try {
    const db = pool.promise();

    // ==========================================================
    // THE UBER LOCK: PREVENT MULTIPLE ACTIVE ASSETS
    // ==========================================================
    const [[activeRide]] = await db.query(
      `SELECT id FROM rides WHERE user_id = ? AND ride_status = 'active' LIMIT 1`,
      [userId]
    );

    if (activeRide) {
      return res.status(403).json({ 
        success: false, 
        message: 'End Ride First' 
      });
    }
    // ==========================================================

    const [[userRow]] = await db.query(
      'SELECT id FROM users WHERE id = ? LIMIT 1',
      [userId]
    );

    if (!userRow) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    const [[bikeRow]] = await db.query(
      `SELECT id, status, current_station_id
       FROM bikes
       WHERE id = ?
       LIMIT 1`,
      [bikeId]
    );

    if (!bikeRow) {
      return res.status(404).json({
        success: false,
        message: 'Bike not found.',
      });
    }

    if (bikeRow.status !== 'available') {
      return res.status(409).json({
        success: false,
        message: 'Bike is currently in active use. Please choose another bike.',
      });
    }

    if (!bikeRow.current_station_id) {
      return res.status(409).json({
        success: false,
        message: 'Bike has no assigned pickup station.',
      });
    }

    await db.query(
      `INSERT INTO user_bike_selections (user_id, bike_id, pickup_station_id, status)
       VALUES (?, ?, ?, 'selected')
       ON DUPLICATE KEY UPDATE
         bike_id = VALUES(bike_id),
         pickup_station_id = VALUES(pickup_station_id),
         dropoff_station_id = NULL,
         use_custom_dropoff = 0,
         arrival_note = NULL,
         status = 'selected'`,
      [userId, bikeId, bikeRow.current_station_id]
    );

    return res.status(200).json({
      success: true,
      message: 'Bike selected. Continue to confirmation stage.',
      data: {
        user_id: userId,
        bike_id: bikeId,
        status: 'selected',
      },
    });
  } catch (error) {
    console.error('selectBikeForUser error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to select bike.',
    });
  }
};

module.exports = {
  listPickupStations,
  listBookableBikes,
  selectBikeForUser,
};