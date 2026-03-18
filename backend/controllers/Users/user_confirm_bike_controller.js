const pool = require('../../config/db');

// ============================================================================
// 1. GET PENDING SELECTION
// Fetches the bike the user has currently locked in the staging table.
// ============================================================================
const getPendingSelection = async (req, res) => {
  const userId = parseInt(req.query.user_id, 10);
  
  if (!userId) {
    return res.status(400).json({ success: false, message: 'User ID required.' });
  }

  try {
    const db = pool.promise();
    const [[selection]] = await db.query(
      `SELECT 
         ubs.id, 
         ubs.bike_id, 
         ubs.pickup_station_id, 
         b.bike_name, 
         b.bike_code, 
         b.bike_image, 
         b.battery_level, 
         s.station_name AS pickup_name
       FROM user_bike_selections ubs
       JOIN bikes b ON ubs.bike_id = b.id
       JOIN stations s ON ubs.pickup_station_id = s.id
       WHERE ubs.user_id = ? AND ubs.status = 'selected'
       LIMIT 1`,
      [userId]
    );

    if (!selection) {
      return res.status(404).json({ success: false, message: 'No pending bike selection found.' });
    }

    return res.status(200).json({ success: true, data: selection });
  } catch (error) {
    console.error('getPendingSelection error:', error);
    return res.status(500).json({ success: false, message: 'Database error.' });
  }
};

// ============================================================================
// 2. GET DROPOFF STATIONS
// Fetches all active stations where a user is allowed to end a ride.
// ============================================================================
const getDropoffStations = async (req, res) => {
  try {
    const db = pool.promise();
    
    // We pull stations that are explicitly marked for dropoff or both
    const [stations] = await db.query(
      `SELECT id, station_name, latitude, longitude 
       FROM stations 
       WHERE status = 'active' AND station_type IN ('dropoff', 'both')
       ORDER BY station_name ASC`
    );
    
    return res.status(200).json({ success: true, stations });
  } catch (error) {
    console.error('getDropoffStations error:', error);
    return res.status(500).json({ success: false, message: 'Failed to load drop-off stations.' });
  }
};

// ============================================================================
// 3. GET FARE ESTIMATE (THE FIXED ROUTE UPGRADE)
// Queries the admin's transport_prices table to find the exact cost.
// ============================================================================
const getFareEstimate = async (req, res) => {
  const { pickup_id, dropoff_id } = req.body;
  
  if (!pickup_id || !dropoff_id) {
    return res.status(400).json({ success: false, message: 'Missing station IDs.' });
  }

  try {
    const db = pool.promise();
    
    // THE FIX: Pull allocated_time instead of the deprecated column
    const [[routePrice]] = await db.query(
      `SELECT price_cedis, allocated_time 
       FROM transport_prices 
       WHERE from_station_id = ? 
         AND to_station_id = ? 
         AND status = 'active'
       LIMIT 1`, 
      [pickup_id, dropoff_id]
    );

    if (!routePrice) {
      // Brutal honesty: If the admin didn't price the route, the route doesn't exist.
      return res.status(404).json({ 
        success: false, 
        message: 'This specific route is currently unavailable or not configured.' 
      });
    }

    const finalPrice = Number.parseFloat(routePrice.price_cedis).toFixed(2);

    return res.status(200).json({ 
      success: true, 
      estimate: finalPrice, 
      allocated_time: routePrice.allocated_time // THE FIX: Send raw seconds to Flutter
    });
  } catch (error) {
    console.error("Fare error:", error);
    return res.status(500).json({ success: false, message: 'Failed to retrieve route pricing.' });
  }
};

// ============================================================================
// 4. CONFIRM SELECTION
// Locks in the dropoff station and prepares the user for payment.
// ============================================================================
const confirmSelection = async (req, res) => {
  const userId = parseInt(req.body.user_id, 10);
  const dropoffStationId = parseInt(req.body.dropoff_station_id, 10);

  if (!userId || !dropoffStationId) {
    return res.status(400).json({ success: false, message: 'Valid user ID and drop-off station required.' });
  }

  try {
    const db = pool.promise();
    
    const [result] = await db.query(
      `UPDATE user_bike_selections 
       SET dropoff_station_id = ?, status = 'confirmed' 
       WHERE user_id = ? AND status = 'selected'`,
      [dropoffStationId, userId]
    );

    if (result.affectedRows === 0) {
      return res.status(400).json({ success: false, message: 'Invalid or expired selection. Please re-select a bike.' });
    }
    
    return res.status(200).json({ success: true, message: 'Bike confirmed. Proceeding to payment.' });
  } catch (error) {
    console.error('confirmSelection error:', error);
    return res.status(500).json({ success: false, message: 'Confirmation failed.' });
  }
};

// ============================================================================
// 5. CANCEL SELECTION (THE BIN)
// Drops the staging row and frees the bike back to the 'available' pool.
// ============================================================================
const cancelSelection = async (req, res) => {
  const userId = parseInt(req.body.user_id, 10);
  const bikeId = parseInt(req.body.bike_id, 10);
  
  if (!userId || !bikeId) {
    return res.status(400).json({ success: false, message: 'Valid user ID and bike ID required.' });
  }

  const connection = await pool.promise().getConnection();

  try {
    // START TRANSACTION to ensure we don't delete the selection but fail to free the bike
    await connection.beginTransaction();

    // 1. Delete the staging selection
    const [deleteResult] = await connection.query(
      `DELETE FROM user_bike_selections WHERE user_id = ? AND status = 'selected'`, 
      [userId]
    );
    
    // Only free the bike if we actually deleted a selection holding it
    if (deleteResult.affectedRows > 0) {
      // 2. Free the bike back to the available pool
      await connection.query(
        `UPDATE bikes SET status = 'available' WHERE id = ?`, 
        [bikeId]
      );
    }

    // COMMIT changes permanently
    await connection.commit();
    return res.status(200).json({ success: true, message: 'Selection cancelled successfully.' });
    
  } catch (error) {
    await connection.rollback();
    console.error('cancelSelection error:', error);
    return res.status(500).json({ success: false, message: 'Failed to cancel selection.' });
  } finally {
    connection.release();
  }
};

module.exports = {
  getPendingSelection,
  getDropoffStations,
  getFareEstimate,
  confirmSelection,
  cancelSelection
};