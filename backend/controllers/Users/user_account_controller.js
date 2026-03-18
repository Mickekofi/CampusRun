const pool = require('../../config/db');

// ============================================================================
// HELPER: CALCULATE RIDER SCORE & GRADE
// Base score is 70. Rides add points (+2). Violations destroy points (-15).
// ============================================================================
const calculateRiderGrade = (totalRides, totalViolations) => {
  let score = 70 + (totalRides * 2) - (totalViolations * 15);
  
  if (score > 100) score = 100;
  if (score < 0) score = 0;

  let grade = 'E';
  let title = 'Very Bad';
  let colorHex = '0xFFE60000'; // AppBrandColors.redYellowStart (Red)

  if (score >= 90) { grade = 'A'; title = 'Expert Rider'; colorHex = '0xFF00FF00'; } // Green
  else if (score >= 80) { grade = 'B+'; title = 'Great'; colorHex = '0xFF00FF00'; }
  else if (score >= 70) { grade = 'B'; title = 'Good'; colorHex = '0xFF00FF00'; }
  else if (score >= 60) { grade = 'C+'; title = 'Average'; colorHex = '0xFFFFCC00'; } // Yellow
  else if (score >= 50) { grade = 'C'; title = 'Fair'; colorHex = '0xFFFFCC00'; }
  else if (score >= 40) { grade = 'D+'; title = 'Warning'; colorHex = '0xFFFF9900'; } // Orange
  else if (score >= 30) { grade = 'D'; title = 'Poor'; colorHex = '0xFFE60000'; }

  return { score, grade, title, colorHex };
};

// ============================================================================
// 1. GET USER PROFILE & METRICS
// ============================================================================
const getUserProfile = async (req, res) => {
  const userId = parseInt(req.query.user_id, 10);
  if (!userId) return res.status(400).json({ success: false, message: 'User ID required' });

  try {
    const db = pool.promise();

    // 1. Fetch User Data
    const [[user]] = await db.query(
      `SELECT id, full_name, student_id, email, profile_picture, account_status, wallet_balance 
       FROM users WHERE id = ? LIMIT 1`,
      [userId]
    );

    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    // 2. Count Total Rides
    const [[rides]] = await db.query(
      `SELECT COUNT(*) as count FROM rides WHERE user_id = ? AND ride_status = 'completed'`,
      [userId]
    );
    const totalRides = rides.count || 0;

    // 3. Count Violations (Assumes penalties are tracked in wallet_transactions)
    const [[violations]] = await db.query(
      `SELECT COUNT(*) as count FROM wallet_transactions WHERE user_id = ? AND transaction_type = 'penalty'`,
      [userId]
    );
    const totalViolations = violations.count || 0;

    // 4. Calculate the Gamified Grade
    const rating = calculateRiderGrade(totalRides, totalViolations);

    return res.status(200).json({
      success: true,
      data: {
        profile: user,
        stats: {
          total_rides: totalRides,
          total_violations: totalViolations
        },
        rating: rating
      }
    });

  } catch (error) {
    console.error('getUserProfile error:', error);
    return res.status(500).json({ success: false, message: 'Database error.' });
  }
};

module.exports = {
  getUserProfile
};