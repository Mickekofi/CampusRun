const bcrypt = require('bcryptjs');
const pool = require('../config/db');

const UEW_STUDENT_EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@st\.uew\.edu\.gh$/;

const signup = async (req, res) => {
  const { student_id: studentId, email, password } = req.body || {};

  if (!studentId || !email || !password) {
    return res.status(400).json({
      success: false,
      message: 'student_id, email, and password are required.',
    });
  }

  if (!UEW_STUDENT_EMAIL_REGEX.test(String(email).trim())) {
    return res.status(400).json({
      success: false,
      message: 'Use a valid UEW email ending with @st.uew.edu.gh',
    });
  }

  if (String(password).length < 6) {
    return res.status(400).json({
      success: false,
      message: 'Password must be at least 6 characters.',
    });
  }

  try {
    const db = pool.promise();

    const [existingUsers] = await db.query(
      'SELECT id, student_id, email FROM users WHERE student_id = ? OR email = ? LIMIT 1',
      [String(studentId).trim(), String(email).trim().toLowerCase()]
    );

    if (existingUsers.length > 0) {
      const existing = existingUsers[0];
      if (existing.student_id === String(studentId).trim()) {
        return res.status(409).json({
          success: false,
          message: 'Student ID already exists.',
        });
      }

      return res.status(409).json({
        success: false,
        message: 'Email already exists.',
      });
    }

    const passwordHash = await bcrypt.hash(String(password), 10);

    await db.query(
      'INSERT INTO users (student_id, full_name, email, phone, password_hash) VALUES (?, ?, ?, ?, ?)',
      [
        String(studentId).trim(),
        'New User',
        String(email).trim().toLowerCase(),
        `TMP-${Date.now()}`,
        passwordHash,
      ]
    );

    return res.status(201).json({
      success: true,
      message: 'Signup successful.',
    });
  } catch (error) {
    if (error && error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'Student ID, email, or phone already exists.',
      });
    }

    console.error('Signup error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error during signup.',
    });
  }
};

module.exports = { signup };
