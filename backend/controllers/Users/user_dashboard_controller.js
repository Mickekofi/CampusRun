// the user dashboard controller js
const pool = require('../../config/db');

const toInt = (value) => {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : 0;
};

const getUserDashboardOverview = async (req, res) => {
  const userIdRaw = req.query.user_id ?? req.params.userId;
  const userId = Number.parseInt(userIdRaw, 10);

  if (!Number.isFinite(userId) || userId <= 0) {
    return res.status(400).json({
      success: false,
      message: 'A valid user_id is required.',
    });
  }

  try {
    const db = pool.promise();

    const [[userRow]] = await db.query(
      `SELECT
         id,
         student_id,
         full_name,
         account_status,
         wallet_balance,
         profile_picture
       FROM users
       WHERE id = ?
       LIMIT 1`,
      [userId]
    );

    if (!userRow) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    const [[rideSummary]] = await db.query(
      `SELECT
         COUNT(*) AS total_rides,
         SUM(CASE WHEN ride_status = 'active' THEN 1 ELSE 0 END) AS active_rides,
         SUM(CASE WHEN ride_status = 'completed' THEN 1 ELSE 0 END) AS completed_rides,
         SUM(CASE WHEN ride_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_rides
       FROM rides
       WHERE user_id = ?`,
      [userId]
    );

    const [[reservationSummary]] = await db.query(
      `SELECT
         SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active_reservations,
         SUM(CASE WHEN status = 'expired' THEN 1 ELSE 0 END) AS expired_reservations,
         SUM(CASE WHEN status = 'converted' THEN 1 ELSE 0 END) AS converted_reservations
       FROM reservations
       WHERE user_id = ?`,
      [userId]
    );

    const [[lastRide]] = await db.query(
      `SELECT
         id,
         ride_code,
         start_time,
         end_time,
         total_fare,
         ride_status
       FROM rides
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT 1`,
      [userId]
    );

    return res.status(200).json({
      success: true,
      data: {
        profile: {
          id: toInt(userRow.id),
          student_id: userRow.student_id,
          full_name: userRow.full_name,
          account_status: userRow.account_status,
          wallet_balance: Number.parseFloat(userRow.wallet_balance ?? 0),
          profile_picture: userRow.profile_picture,
        },
        metrics: {
          total_rides: toInt(rideSummary?.total_rides),
          active_rides: toInt(rideSummary?.active_rides),
          completed_rides: toInt(rideSummary?.completed_rides),
          cancelled_rides: toInt(rideSummary?.cancelled_rides),
          active_reservations: toInt(reservationSummary?.active_reservations),
          expired_reservations: toInt(reservationSummary?.expired_reservations),
          converted_reservations: toInt(reservationSummary?.converted_reservations),
        },
        last_ride: lastRide || null,
      },
    });
  } catch (error) {
    console.error('User dashboard overview error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to load user dashboard overview.',
    });
  }
};

module.exports = {
  getUserDashboardOverview,
};
