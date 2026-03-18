/*
 * admin_live_tracker_controller.js
 * -----------------------------------------------------------------------
 * Handles all backend logic for the Admin Live Tracker feature.
 *
 * SECTION 1 — SHARED UTILITIES    : helpers used across this file
 * SECTION 2 — TABLE SETUP         : ensures required DB tables exist
 * SECTION 3 — GET ACTIVE RIDERS   : list users currently in ride-mode
 * SECTION 4 — UPSERT LOCATION     : receive live GPS from user app
 * SECTION 5 — GET RIDER TRAIL     : fetch recent location history
 * SECTION 6 — EXPORTS             : expose endpoints to the router
 * -----------------------------------------------------------------------
 */

const pool = require('../../config/db');

// ═══════════════════════════════════════════════════════════════════════
// SECTION 1 — SHARED UTILITIES
// ═══════════════════════════════════════════════════════════════════════

/**
 * Extracts the real client IP from the request, accounting for proxies.
 */
const getClientIp = (req) => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || null;
};

/**
 * Parses a float from a value and returns null if invalid.
 */
const safeFloat = (val) => {
  const n = parseFloat(val);
  return Number.isFinite(n) ? n : null;
};

/**
 * Number of minutes before a rider location entry is considered stale.
 * Riders idle for longer than this threshold are excluded from "active".
 */
const LOCATION_STALE_MINUTES = 10;

/**
 * How many trail points to return per rider history request.
 */
const TRAIL_LIMIT = 100;

// ═══════════════════════════════════════════════════════════════════════
// SECTION 2 — TABLE SETUP
// ═══════════════════════════════════════════════════════════════════════

/**
 * Creates the two tables required by the live tracker if they do not
 * already exist:
 *
 *   user_location_latest
 *     One row per user — upserted on every location push.
 *     Used for the real-time map view (fast single-row lookup per user).
 *
 *   user_location_trail
 *     Append-only history table for drawing the path line on the map.
 *     Automatically trimmed to the newest TRAIL_LIMIT rows per user via
 *     the trimRiderTrail helper called inside upsertRiderLocation.
 */
const ensureTrackerTables = async () => {
  const db = pool.promise();

  // Latest-position snapshot (one row per user, fast upsert target)
  await db.query(`
    CREATE TABLE IF NOT EXISTS user_location_latest (
      user_id        BIGINT UNSIGNED NOT NULL,
      latitude       DECIMAL(10,8) NOT NULL,
      longitude      DECIMAL(11,8) NOT NULL,
      accuracy       FLOAT         NULL,
      speed_kmh      FLOAT         NULL,
      heading        FLOAT         NULL,
      battery_pct    TINYINT       NULL,
      is_riding      TINYINT(1)    NOT NULL DEFAULT 1,
      updated_at     DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                                   ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);

  // Append-only trail history (used to draw polyline on map)
  await db.query(`
    CREATE TABLE IF NOT EXISTS user_location_trail (
      id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
      user_id     BIGINT UNSIGNED NOT NULL,
      latitude    DECIMAL(10,8) NOT NULL,
      longitude   DECIMAL(11,8) NOT NULL,
      accuracy    FLOAT         NULL,
      speed_kmh   FLOAT         NULL,
      heading     FLOAT         NULL,
      recorded_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      INDEX idx_user_trail (user_id, recorded_at),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `);
};

// Initialise tables on module load (non-blocking — server starts regardless)
ensureTrackerTables().catch((err) =>
  console.error('[LiveTracker] Table setup error:', err.message)
);

// ═══════════════════════════════════════════════════════════════════════
// SECTION 3 — GET ACTIVE RIDERS
// ═══════════════════════════════════════════════════════════════════════

/**
 * GET /api/admin_live_tracker_routes/active-riders
 *
 * Returns every user that has pushed a location update within the last
 * LOCATION_STALE_MINUTES minutes and whose is_riding flag is set to 1.
 *
 * Response shape:
 *   {
 *     success: true,
 *     total: <number>,
 *     riders: [
 *       {
 *         user_id, student_id, full_name, profile_picture,
 *         account_status, latitude, longitude, accuracy,
 *         speed_kmh, heading, battery_pct, updated_at
 *       }, ...
 *     ]
 *   }
 */
const getActiveRiders = async (_req, res) => {
  try {
    const db = pool.promise();

    const staleThreshold = new Date(
      Date.now() - LOCATION_STALE_MINUTES * 60 * 1000
    );

    const [rows] = await db.query(
      `SELECT
         u.id            AS user_id,
         u.student_id,
         u.full_name,
         u.profile_picture,
         u.account_status,
         ll.latitude,
         ll.longitude,
         ll.accuracy,
         ll.speed_kmh,
         ll.heading,
         ll.battery_pct,
         ll.is_riding,
         ll.updated_at
       FROM user_location_latest ll
       JOIN users u ON u.id = ll.user_id
       WHERE ll.is_riding = 1
         AND ll.updated_at >= ?
       ORDER BY ll.updated_at DESC`,
      [staleThreshold]
    );

    return res.status(200).json({
      success: true,
      total: rows.length,
      riders: rows,
    });
  } catch (err) {
    console.error('[LiveTracker] getActiveRiders error:', err.message);
    return res.status(500).json({ success: false, message: 'Failed to load active riders.' });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SECTION 4 — UPSERT LOCATION (called by user_ridemode_screen)
// ═══════════════════════════════════════════════════════════════════════

/**
 * POST /api/admin_live_tracker_routes/location
 *
 * Accepts a single GPS ping from a rider and:
 *   1. Upserts their row in user_location_latest
 *   2. Appends a row to user_location_trail for path drawing
 *
 * Body:
 *   {
 *     user_id      : number  (required)
 *     latitude     : number  (required, −90 to 90)
 *     longitude    : number  (required, −180 to 180)
 *     accuracy     : number? (metres)
 *     speed_kmh    : number? (km/h)
 *     heading      : number? (degrees 0–360)
 *     battery_pct  : number? (0–100)
 *     is_riding    : 0|1     (default 1; send 0 when user ends ride)
 *   }
 */
const upsertRiderLocation = async (req, res) => {
  try {
    const db = pool.promise();

    const userId = parseInt(req.body?.user_id, 10);
    const lat = safeFloat(req.body?.latitude);
    const lng = safeFloat(req.body?.longitude);

    // ── Validate required fields ──────────────────────────────────────
    if (!Number.isFinite(userId) || userId <= 0) {
      return res.status(400).json({ success: false, message: 'valid user_id required.' });
    }
    if (lat === null || lng === null) {
      return res.status(400).json({ success: false, message: 'latitude and longitude are required.' });
    }
    if (lat < -90 || lat > 90) {
      return res.status(400).json({ success: false, message: 'latitude must be between -90 and 90.' });
    }
    if (lng < -180 || lng > 180) {
      return res.status(400).json({ success: false, message: 'longitude must be between -180 and 180.' });
    }

    // ── Optional fields ───────────────────────────────────────────────
    const accuracy   = safeFloat(req.body?.accuracy);
    const speedKmh   = safeFloat(req.body?.speed_kmh);
    const heading    = safeFloat(req.body?.heading);
    const batteryPct = req.body?.battery_pct !== undefined
      ? Math.min(100, Math.max(0, parseInt(req.body.battery_pct, 10)))
      : null;
    const isRiding = req.body?.is_riding === 0 || req.body?.is_riding === '0' ? 0 : 1;

    // ── Verify user exists ────────────────────────────────────────────
    const [[user]] = await db.query(
      'SELECT id FROM users WHERE id = ? LIMIT 1',
      [userId]
    );
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    // ── Upsert latest position ────────────────────────────────────────
    await db.query(
      `INSERT INTO user_location_latest
         (user_id, latitude, longitude, accuracy, speed_kmh, heading, battery_pct, is_riding, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
       ON DUPLICATE KEY UPDATE
         latitude    = VALUES(latitude),
         longitude   = VALUES(longitude),
         accuracy    = VALUES(accuracy),
         speed_kmh   = VALUES(speed_kmh),
         heading     = VALUES(heading),
         battery_pct = VALUES(battery_pct),
         is_riding   = VALUES(is_riding),
         updated_at  = NOW()`,
      [userId, lat, lng, accuracy, speedKmh, heading, batteryPct, isRiding]
    );

    // ── Append to trail history ───────────────────────────────────────
    if (isRiding === 1) {
      await db.query(
        `INSERT INTO user_location_trail
           (user_id, latitude, longitude, accuracy, speed_kmh, heading)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [userId, lat, lng, accuracy, speedKmh, heading]
      );

      // Trim old trail entries – keep only the latest TRAIL_LIMIT rows
      await db.query(
        `DELETE FROM user_location_trail
         WHERE user_id = ?
           AND id NOT IN (
             SELECT id FROM (
               SELECT id
               FROM user_location_trail
               WHERE user_id = ?
               ORDER BY recorded_at DESC
               LIMIT ?
             ) AS keep_rows
           )`,
        [userId, userId, TRAIL_LIMIT]
      );
    }

    return res.status(200).json({ success: true, message: 'Location updated.' });
  } catch (err) {
    console.error('[LiveTracker] upsertRiderLocation error:', err.message);
    return res.status(500).json({ success: false, message: 'Failed to save location.' });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SECTION 5 — GET RIDER TRAIL
// ═══════════════════════════════════════════════════════════════════════

/**
 * GET /api/admin_live_tracker_routes/rider/:userId/trail
 *
 * Returns the most recent trail points for a specific rider so the
 * admin map can draw a polyline showing the path taken.
 *
 * Query params:
 *   limit  — number of points to return (default TRAIL_LIMIT, max 500)
 *
 * Response shape:
 *   {
 *     success: true,
 *     user_id: number,
 *     trail: [{ latitude, longitude, speed_kmh, heading, recorded_at }, ...]
 *   }
 */
const getRiderTrail = async (req, res) => {
  try {
    const db = pool.promise();

    const userId = parseInt(req.params.userId, 10);
    if (!Number.isFinite(userId) || userId <= 0) {
      return res.status(400).json({ success: false, message: 'Invalid userId.' });
    }

    const rawLimit = parseInt(req.query.limit, 10);
    const limit = Number.isFinite(rawLimit) && rawLimit > 0
      ? Math.min(rawLimit, 500)
      : TRAIL_LIMIT;

    const [rows] = await db.query(
      `SELECT latitude, longitude, accuracy, speed_kmh, heading, recorded_at
       FROM user_location_trail
       WHERE user_id = ?
       ORDER BY recorded_at DESC
       LIMIT ?`,
      [userId, limit]
    );

    // Reverse so the trail is in chronological order (oldest → newest)
    const trail = rows.reverse();

    return res.status(200).json({
      success: true,
      user_id: userId,
      trail,
    });
  } catch (err) {
    console.error('[LiveTracker] getRiderTrail error:', err.message);
    return res.status(500).json({ success: false, message: 'Failed to load trail.' });
  }
};

// ═══════════════════════════════════════════════════════════════════════
// SECTION 6 — EXPORTS
// ═══════════════════════════════════════════════════════════════════════

module.exports = {
  getActiveRiders,
  upsertRiderLocation,
  getRiderTrail,
};
