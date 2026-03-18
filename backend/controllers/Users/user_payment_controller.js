// the user payment controller js

const pool = require('../../config/db');

// ============================================================================
// HELPER: GENERATE PAYMENT REFERENCE
// ============================================================================
const generatePaymentReference = (userId) => {
  const timestamp = Date.now();
  const randomStr = Math.random().toString(36).slice(2, 6).toUpperCase();
  return `PAY-${userId}-${timestamp}-${randomStr}`;
};

// ============================================================================
// 1. GET PAYMENT DETAILS
// Pulls the confirmed selection and calculates the exact fixed price to display.
// ============================================================================
const getPaymentDetails = async (req, res) => {
  const userId = parseInt(req.query.user_id, 10);

  if (!userId) {
    return res.status(400).json({ success: false, message: 'User ID is required.' });
  }

  try {
    const db = pool.promise();

    // 1. Get the user's confirmed selection
    const [[selection]] = await db.query(
      `SELECT ubs.pickup_station_id, ubs.dropoff_station_id, s_pickup.station_name AS pickup_name, s_dropoff.station_name AS dropoff_name
       FROM user_bike_selections ubs
       JOIN stations s_pickup ON ubs.pickup_station_id = s_pickup.id
       JOIN stations s_dropoff ON ubs.dropoff_station_id = s_dropoff.id
       WHERE ubs.user_id = ? AND ubs.status = 'confirmed'
       LIMIT 1`,
      [userId]
    );

    if (!selection) {
      return res.status(404).json({ success: false, message: 'No confirmed bike selection found.' });
    }

    // 2. Look up the exact price for this route from the transport_prices table
    const [[routePrice]] = await db.query(
      `SELECT price_cedis 
       FROM transport_prices 
       WHERE from_station_id = ? AND to_station_id = ? AND status = 'active'
       LIMIT 1`,
      [selection.pickup_station_id, selection.dropoff_station_id]
    );

    if (!routePrice) {
      return res.status(400).json({ success: false, message: 'Pricing for this route is unavailable.' });
    }

    const fare = Number.parseFloat(routePrice.price_cedis).toFixed(2);

    return res.status(200).json({
      success: true,
      data: {
        journey_text: `From ${selection.pickup_name} to ${selection.dropoff_name}`,
        fare_amount: fare,
      }
    });

  } catch (error) {
    console.error('getPaymentDetails error:', error);
    return res.status(500).json({ success: false, message: 'Failed to load payment details.' });
  }
};

// ============================================================================
// 2. AUTHORIZE MOMO PAYMENT
// Creates a 'pending' payment record to prepare for the QR scan.
// ============================================================================
const authorizeMoMoPayment = async (req, res) => {
  const { user_id, amount, phone, network } = req.body;

  if (!user_id || !amount || !phone) {
    return res.status(400).json({ success: false, message: 'Missing payment details.' });
  }

  try {
    const db = pool.promise();

    // Double check they actually have a confirmed bike before letting them pay
    const [[selection]] = await db.query(
      `SELECT id FROM user_bike_selections WHERE user_id = ? AND status = 'confirmed' LIMIT 1`,
      [user_id]
    );

    if (!selection) {
      return res.status(400).json({ success: false, message: 'You must confirm a bike first.' });
    }

    // Generate a unique reference for tracking
    const paymentRef = generatePaymentReference(user_id);

    // Insert a PENDING payment. The QR scanner will turn this to 'successful'.
    await db.query(
      `INSERT INTO payments 
       (payment_reference, user_id, amount, payment_method, transaction_type, payment_status, external_reference)
       VALUES (?, ?, ?, 'momo', 'ride_payment', 'pending', ?)`,
      [paymentRef, user_id, amount, `${network} - ${phone}`]
    );

    return res.status(200).json({
      success: true,
      message: 'Payment authorized. Proceed to scan.',
      payment_reference: paymentRef
    });

  } catch (error) {
    console.error('authorizeMoMoPayment error:', error);
    return res.status(500).json({ success: false, message: 'Failed to authorize payment.' });
  }
};

module.exports = {
  getPaymentDetails,
  authorizeMoMoPayment
};