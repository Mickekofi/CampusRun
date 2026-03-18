const pool = require('../../config/db');

// Helper to generate a unique transaction ID
const generateTxnRef = (userId) => {
  return `TXN-RIDE-${userId}-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;
};
const generateRideCode = (userId) => {
  return `RD-${userId}-${Date.now()}`;
};

const processQRScanAndStartRide = async (req, res) => {
  const { user_id, bike_code } = req.body;
  const userId = parseInt(user_id, 10);

  if (!userId || !bike_code) {
    return res.status(400).json({ success: false, message: 'Invalid scan data.' });
  }

  const connection = await pool.promise().getConnection();

  try {
    await connection.beginTransaction();

    // ==========================================================
    // 0. THE UBER LOCK: PREVENT DOUBLE BOOKINGS AT THE SCAN LEVEL
    // ==========================================================
    const [[existingRide]] = await connection.query(
      `SELECT id FROM rides WHERE user_id = ? AND ride_status = 'active' LIMIT 1 FOR UPDATE`,
      [userId]
    );

    if (existingRide) {
      await connection.rollback();
      return res.status(403).json({ 
        success: false, 
        message: 'CRITICAL: You already have an active ride. End it first.' 
      });
    }

    // ==========================================================
    // 1. ASSET VERIFICATION & LOCK
    // ==========================================================
    const [[bike]] = await connection.query(
      `SELECT id, status FROM bikes WHERE bike_code = ? LIMIT 1 FOR UPDATE`,
      [bike_code]
    );

    if (!bike) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'Invalid QR Code. Bike not found in system.' });
    }

    if (bike.status === 'active' || bike.status === 'maintenance' || bike.status === 'tampered' || bike.status === 'inactive') {
      await connection.rollback();
      return res.status(409).json({ 
        success: false, 
        message: `Asset Locked. This bike is currently marked as: ${bike.status}.` 
      });
    }

    // ==========================================================
    // 2. VERIFY USER SELECTION
    // ==========================================================
    const [[selection]] = await connection.query(
      `SELECT id, pickup_station_id, dropoff_station_id 
       FROM user_bike_selections 
       WHERE user_id = ? AND bike_id = ? AND status = 'confirmed' 
       FOR UPDATE`,
      [userId, bike.id]
    );

    if (!selection) {
      await connection.rollback();
      return res.status(400).json({ success: false, message: 'You have not confirmed this specific bike. Please check your selection.' });
    }

    // ==========================================================
    // 2.5 FETCH ADMIN ALLOCATED TIME FOR THE ROUTE
    // ==========================================================
    const [[routePrice]] = await connection.query(
      `SELECT allocated_time 
       FROM transport_prices 
       WHERE from_station_id = ? AND to_station_id = ? AND status = 'active' 
       LIMIT 1`,
      [selection.pickup_station_id, selection.dropoff_station_id]
    );

    // The Fail-Safe: If Admin didn't set a time, force 660 seconds (11 mins) to protect the penalty engine
    const allocatedTime = routePrice?.allocated_time ? routePrice.allocated_time : 660;

    // ==========================================================
    // 3. FIND PENDING PAYMENT
    // ==========================================================
    const [[pendingPayment]] = await connection.query(
      `SELECT id, amount, payment_reference 
       FROM payments 
       WHERE user_id = ? AND payment_status = 'pending' AND transaction_type = 'ride_payment' 
       ORDER BY created_at DESC LIMIT 1 
       FOR UPDATE`,
      [userId]
    );

    if (!pendingPayment) {
      await connection.rollback();
      return res.status(400).json({ success: false, message: 'No authorized payment found. Please authorize the ride first.' });
    }

    const fareAmount = parseFloat(pendingPayment.amount);

    // ==========================================================
    // 4. SOLVENCY CHECK
    // ==========================================================
    const [[user]] = await connection.query(
      `SELECT wallet_balance FROM users WHERE id = ? FOR UPDATE`,
      [userId]
    );

    const currentBalance = parseFloat(user.wallet_balance);

    if (currentBalance < fareAmount) {
      await connection.rollback();
      return res.status(402).json({ success: false, message: `Insufficient wallet balance. You need GHS ${fareAmount.toFixed(2)}.` });
    }

    // ==========================================================
    // 5. EXECUTE THE ATOMIC SWAP
    // ==========================================================
    
    // A. Create the Active Ride Record (NOW WITH ALLOCATED TIME)
    const rideCode = generateRideCode(userId);
    const [rideResult] = await connection.query(
      `INSERT INTO rides 
       (ride_code, user_id, bike_id, pickup_station_id, drop_station_id, start_time, base_fare, total_fare, ride_status, allocated_time) 
       VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, 'active', ?)`,
      [rideCode, userId, bike.id, selection.pickup_station_id, selection.dropoff_station_id, fareAmount, fareAmount, allocatedTime]
    );
    const newRideId = rideResult.insertId;

    // B. Deduct the Wallet Balance
    const newBalance = currentBalance - fareAmount;
    await connection.query(
      `UPDATE users SET wallet_balance = ? WHERE id = ?`,
      [newBalance, userId]
    );

    // C. Write to the Immutable Wallet Audit Ledger
    const txnRef = generateTxnRef(userId);
    await connection.query(
      `INSERT INTO wallet_transactions 
       (transaction_reference, user_id, payment_id, ride_id, transaction_type, amount, balance_before, balance_after) 
       VALUES (?, ?, ?, ?, 'debit', ?, ?, ?)`,
      [txnRef, userId, pendingPayment.id, newRideId, fareAmount, currentBalance, newBalance]
    );

    // D. Update Payment Record to Successful
    await connection.query(
      `UPDATE payments 
       SET payment_status = 'successful', ride_id = ?, payment_method = 'wallet' 
       WHERE id = ?`,
      [newRideId, pendingPayment.id]
    );

    // E. Change Bike Status to Active
    const [bikeUpdate] = await connection.query(`UPDATE bikes SET status = 'active' WHERE id = ?`, [bike.id]);
    
    if (bikeUpdate.affectedRows !== 1) {
      await connection.rollback();
      return res.status(500).json({ success: false, message: 'CRITICAL: Failed to update bike status to active.' });
    }

    // F. Delete the staging selection
    await connection.query(`DELETE FROM user_bike_selections WHERE id = ?`, [selection.id]);

    // ==========================================================
    // 6. COMMIT ALL CHANGES
    // ==========================================================
    await connection.commit();

    return res.status(200).json({ 
      success: true, 
      message: 'Ride Started Successfully!',
      ride_code: rideCode
    });

  } catch (error) {
    await connection.rollback();
    console.error('processQRScan error:', error);
    return res.status(500).json({ success: false, message: 'System error during unlock process.' });
  } finally {
    connection.release();
  }
};

module.exports = {
  processQRScanAndStartRide
};