const pool = require('../../config/db');

// ============================================================================
// 1. GET ACTIVE RIDE
// Pulls the student back into Ride Mode and syncs the EXACT dynamic allocated time.
// ============================================================================
const getActiveRide = async (req, res) => {
  const userId = parseInt(req.query.user_id, 10);
  if (!userId) return res.status(400).json({ success: false, message: 'User ID required' });

  try {
    const db = pool.promise();
    
    // THE FIX: Pulling r.allocated_time dynamically. Fallback to 660 ONLY if null.
    const [[activeRide]] = await db.query(
      `SELECT 
         r.id AS ride_id, 
         r.bike_id, 
         r.start_time, 
         b.bike_name, 
         b.battery_level,
         COALESCE(r.allocated_time, 660) AS allocated_time
       FROM rides r 
       JOIN bikes b ON r.bike_id = b.id 
       WHERE r.user_id = ? AND r.ride_status = 'active' 
       LIMIT 1`,
      [userId]
    );

    if (!activeRide) {
      return res.status(404).json({ success: false, message: 'No active ride found.' });
    }

    return res.status(200).json({ success: true, data: activeRide });
  } catch (error) {
    console.error('getActiveRide error:', error);
    return res.status(500).json({ success: false, message: 'Database error.' });
  }
};

// ============================================================================
// 2. SYNC TELEMETRY (LIVE MAP + AUDIT TRAIL)
// Feeds the Admin Live Map AND writes to the permanent bike_telemetry table.
// ============================================================================
const syncTelemetry = async (req, res) => {
  const { bike_id, latitude, longitude, speed_kmh, heading, battery_pct } = req.body;

  if (!bike_id || latitude === undefined || longitude === undefined) {
    return res.status(400).json({ success: false, message: 'Missing telemetry data.' });
  } 

  try {
    const db = pool.promise();
    
    // A. Update the Live Map (bikes table)
    await db.query(
      `UPDATE bikes 
       SET gps_lat = ?, gps_lng = ?, speed_kmh = ?, heading = ?, battery_level = ?, updated_at = NOW() 
       WHERE id = ?`,
      [latitude, longitude, speed_kmh || 0, heading || 0, battery_pct || 100, bike_id]
    );

    // B. Write to the Historical Audit Ledger (bike_telemetry table)
    await db.query(
      `INSERT INTO bike_telemetry 
       (bike_id, gps_lat, gps_lng, battery_level, speed_kmh, lock_status) 
       VALUES (?, ?, ?, ?, ?, 'unlocked')`,
      [bike_id, latitude, longitude, battery_pct || 100, speed_kmh || 0]
    );

    return res.status(200).json({ success: true, message: 'Telemetry synced.' });
  } catch (error) {
    // Fail silently so the Flutter UI does not stutter during the ride
    console.error('syncTelemetry error:', error);
    return res.status(500).json({ success: false, message: 'Failed to sync.' });
  }
};

// ============================================================================
// 3. END RIDE & DYNAMIC PENALTY ENGINE
// Uses the Admin's dynamic time to calculate the scaling penalty.
// ============================================================================
const endRide = async (req, res) => {
  const { user_id, ride_id, bike_id } = req.body;

  if (!user_id || !ride_id || !bike_id) {
    return res.status(400).json({ success: false, message: 'Missing ride details.' });
  }

  const connection = await pool.promise().getConnection();

  try {
    await connection.beginTransaction();

    // 1. Lock the Ride Row and fetch start time AND dynamic allocated time
    const [[ride]] = await connection.query(
      `SELECT start_time, COALESCE(allocated_time, 660) AS allocated_time 
       FROM rides 
       WHERE id = ? AND user_id = ? AND ride_status = 'active' FOR UPDATE`,
      [ride_id, user_id]
    );

    if (!ride) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Active ride not found.' });
    }

    // 2. Calculate Exact Duration
    const startTime = new Date(ride.start_time);
    const endTime = new Date();
    const diffSeconds = Math.floor((endTime - startTime) / 1000);
    const durationMinutes = Math.ceil(diffSeconds / 60);

    // 3. The Scaling Penalty Logic using Dynamic Admin Time
    const ALLOCATED_SECONDS = ride.allocated_time;
    let penaltyAmount = 0.00;
    
    // GHS 1.00 fine for EVERY minute they are late
    const PER_MINUTE_PENALTY = 1.00; 

    if (diffSeconds > ALLOCATED_SECONDS) {
      const lateSeconds = diffSeconds - ALLOCATED_SECONDS;
      const lateMinutes = Math.ceil(lateSeconds / 60);
      penaltyAmount = lateMinutes * PER_MINUTE_PENALTY;
    }

    // 4. Enforce the Penalty (If applicable)
    if (penaltyAmount > 0) {
      // Lock User Row
      const [[user]] = await connection.query(`SELECT wallet_balance FROM users WHERE id = ? FOR UPDATE`, [user_id]);
      const currentBalance = parseFloat(user.wallet_balance);
      const newBalance = currentBalance - penaltyAmount;

      // Deduct Wallet
      await connection.query(`UPDATE users SET wallet_balance = ? WHERE id = ?`, [newBalance, user_id]);

      // Write to Wallet Transactions
      const txnRef = `TXN-PENALTY-${user_id}-${Date.now()}`;
      await connection.query(
        `INSERT INTO wallet_transactions 
         (transaction_reference, user_id, ride_id, transaction_type, amount, balance_before, balance_after) 
         VALUES (?, ?, ?, 'penalty', ?, ?, ?)`,
        [txnRef, user_id, ride_id, penaltyAmount, currentBalance, newBalance]
      );

      // Write to Violations Database
      const violCode = `VIOL-${user_id}-${Date.now()}`;
      await connection.query(
        `INSERT INTO violations 
         (violation_code, user_id, bike_id, ride_id, violation_type, penalty_amount, description, status) 
         VALUES (?, ?, ?, ?, 'Late Return', ?, 'Exceeded dynamic allocated transport time. Wallet auto-deducted.', 'paid')`,
        [violCode, user_id, bike_id, ride_id, penaltyAmount]
      );
    }

    // 5. Close the Ride Ledger
    await connection.query(
      `UPDATE rides 
       SET ride_status = 'completed', end_time = ?, duration_minutes = ?, penalty_amount = ? 
       WHERE id = ?`,
      [endTime, durationMinutes, penaltyAmount, ride_id]
    );

    // 6. Free the Asset (Speed to 0, Status to Available)
    await connection.query(
      `UPDATE bikes 
       SET status = 'available', speed_kmh = 0 
       WHERE id = ?`,
      [bike_id]
    );

    await connection.commit();
    
    return res.status(200).json({ 
      success: true, 
      message: penaltyAmount > 0 
        ? `Ride ended. A late penalty of GHS ${penaltyAmount.toFixed(2)} was applied.` 
        : 'Ride completed successfully.' 
    });

  } catch (error) {
    await connection.rollback();
    console.error('endRide error:', error);
    return res.status(500).json({ success: false, message: 'Failed to end ride.' });
  } finally {
    connection.release();
  }
};

module.exports = {
  getActiveRide,
  syncTelemetry,
  endRide
};