const bcrypt = require('bcryptjs');
const pool = require('../../config/db');

const setUserPassword = async (req, res) => {
  const {
    student_id: studentId,
    email,
    new_password: newPassword,
  } = req.body || {};

  if ((!studentId && !email) || !newPassword) {
    return res.status(400).json({
      success: false,
      message: 'student_id or email, and new_password are required.',
    });
  }

  if (String(newPassword).length < 6) {
    return res.status(400).json({
      success: false,
      message: 'Password must be at least 6 characters.',
    });
  }

  const normalizedEmail = email ? String(email).trim().toLowerCase() : null;
  const normalizedStudentId = studentId ? String(studentId).trim() : null;

  try {
    const db = pool.promise();
    const whereClause = normalizedEmail ? 'LOWER(email) = ?' : 'student_id = ?';
    const whereValue = normalizedEmail || normalizedStudentId;

    const [rows] = await db.query(
      `SELECT id, student_id, full_name, email, phone, profile_picture, account_status FROM users WHERE ${whereClause} LIMIT 1`,
      [whereValue]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found for password setup.',
      });
    }

    const user = rows[0];

    if (user.account_status !== 'active') {
      return res.status(403).json({
        success: false,
        message: 'User account is not active.',
      });
    }

    const passwordHash = await bcrypt.hash(String(newPassword), 10);

    await db.query('UPDATE users SET password_hash = ? WHERE id = ? LIMIT 1', [
      passwordHash,
      user.id,
    ]);

    return res.status(200).json({
      success: true,
      message: 'Password set successfully. You can now login manually.',
      data: {
        id: user.id,
        student_id: user.student_id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        picture: user.profile_picture,
        requires_password_setup: false,
        requires_phone_validation:
          !(user.phone && !String(user.phone).startsWith('TMP')),
      },
    });
  } catch (error) {
    console.error('setUserPassword error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error while setting password.',
    });
  }
};

module.exports = { setUserPassword };
