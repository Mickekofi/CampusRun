const pool = require('../../config/db');

// ============================================================================
// HELPER: GENERATE REFERENCES
// ============================================================================
const generateRef = (prefix, userId) => {
  const timestamp = Date.now();
  const randomStr = Math.random().toString(36).slice(2, 6).toUpperCase();
  return `${prefix}-${userId}-${timestamp}-${randomStr}`;
};

// ============================================================================
// 1. PROCESS DEPOSIT (THE FINANCIAL ENGINE)
// ============================================================================
const processDeposit = async (req, res) => {
  const { user_id, amount, phone, network } = req.body;

  const depositAmount = Number.parseFloat(amount);
  const userId = Number.parseInt(user_id, 10);

  if (!userId || !Number.isFinite(depositAmount) || depositAmount <= 0 || !phone) {
    return res.status(400).json({ success: false, message: 'Invalid deposit details.' });
  }

  const connection = await pool.promise().getConnection();

  try {
    // START TRANSACTION: Financial operations must be atomic
    await connection.beginTransaction();

    // 1. Lock the user row to prevent race conditions during balance calculation
    const [[user]] = await connection.query(
      `SELECT id, wallet_balance FROM users WHERE id = ? FOR UPDATE`,
      [userId]
    );

    if (!user) {
      await connection.rollback();
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const balanceBefore = Number.parseFloat(user.wallet_balance);
    const balanceAfter = balanceBefore + depositAmount;

    // 2. Create the Mock MoMo Payment Record (MVP phase - assumes instant success)
    const paymentRef = generateRef('PAY', userId);
    const [paymentResult] = await connection.query(
      `INSERT INTO payments 
       (payment_reference, user_id, amount, payment_method, transaction_type, payment_status, external_reference)
       VALUES (?, ?, ?, 'momo', 'wallet_topup', 'successful', ?)`,
      [paymentRef, userId, depositAmount, `${network} - ${phone}`]
    );

    // 3. Write to the immutable Wallet Audit Ledger
    const txnRef = generateRef('TXN', userId);
    await connection.query(
      `INSERT INTO wallet_transactions 
       (transaction_reference, user_id, payment_id, transaction_type, amount, balance_before, balance_after)
       VALUES (?, ?, ?, 'topup', ?, ?, ?)`,
      [txnRef, userId, paymentResult.insertId, depositAmount, balanceBefore, balanceAfter]
    );

    // 4. Finally, update the actual wallet balance
    await connection.query(
      `UPDATE users SET wallet_balance = ? WHERE id = ?`,
      [balanceAfter, userId]
    );

    // COMMIT: Save all changes permanently
    await connection.commit();

    return res.status(200).json({
      success: true,
      message: 'Deposit successful.',
      new_balance: balanceAfter.toFixed(2)
    });

  } catch (error) {
    await connection.rollback();
    console.error('processDeposit error:', error);
    return res.status(500).json({ success: false, message: 'Failed to process deposit.' });
  } finally {
    connection.release();
  }
};

module.exports = {
  processDeposit
};