const bcrypt = require('bcryptjs');
const pool = require('../config/db');

const UEW_STUDENT_EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@st\.uew\.edu\.gh$/;
const BCRYPT_HASH_REGEX = /^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$/;

const isPhoneVerified = (phone) => {
  if (phone === null || phone === undefined) return false;
  const normalized = String(phone).trim();
  if (!normalized || normalized.length === 0) return false;
  if (normalized.startsWith('TMP')) return false;
  return true;
};

const hasValidPasswordHash = (passwordHash) => {
  if (passwordHash === null || passwordHash === undefined) return false;
  return BCRYPT_HASH_REGEX.test(String(passwordHash));
};

const google = async (req, res) => {
  const {
    student_id: studentId,
    full_name: fullName,
    email,
    password,
    picture,
  } = req.body || {};

  if (!studentId || !email || !password) {
    return res.status(400).json({
      success: false,
      message: 'student_id, email, and password are required.',
    });
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  const normalizedPicture =
    typeof picture === 'string' && picture.trim().length > 0
      ? picture.trim()
      : null;
  if (!UEW_STUDENT_EMAIL_REGEX.test(normalizedEmail)) {
    return res.status(400).json({
      success: false,
      message: 'Only UEW student emails are allowed (@st.uew.edu.gh).',
    });
  }

  try {
    const db = pool.promise();

    const [existingRows] = await db.query(
      'SELECT id, student_id, full_name, email, profile_picture, phone, password_hash FROM users WHERE student_id = ? OR email = ? LIMIT 1',
      [String(studentId).trim(), normalizedEmail]
    );

    if (existingRows.length > 0) {
      if (normalizedPicture) {
        await db.query('UPDATE users SET profile_picture = ? WHERE id = ?', [
          normalizedPicture,
          existingRows[0].id,
        ]);
      }

      return res.status(200).json({
        success: true,
        message: 'Google user exists. Continue account linking checks.',
        data: {
          id: existingRows[0].id,
          student_id: existingRows[0].student_id,
          full_name: existingRows[0].full_name,
          email: existingRows[0].email,
          phone: isPhoneVerified(existingRows[0].phone)
            ? existingRows[0].phone
            : '',
          picture: normalizedPicture ?? existingRows[0].profile_picture ?? null,
          requires_password_setup: !hasValidPasswordHash(
            existingRows[0].password_hash
          ),
          requires_phone_validation: !isPhoneVerified(existingRows[0].phone),
        },
      });
    }

    const passwordHash = `GOOGLE_AUTH_ONLY::${Date.now()}`;
    const temporaryPhone = `TMP${Date.now().toString().slice(-10)}`;

    await db.query(
      'INSERT INTO users (student_id, full_name, email, profile_picture, phone, password_hash) VALUES (?, ?, ?, ?, ?, ?)',
      [
        String(studentId).trim(),
        String(fullName || 'Google User').trim(),
        normalizedEmail,
        normalizedPicture,
        temporaryPhone,
        passwordHash,
      ]
    );

    return res.status(201).json({
      success: true,
      message: 'Google sign-in profile saved successfully.',
      data: {
        id: null,
        student_id: String(studentId).trim(),
        full_name: String(fullName || 'Google User').trim(),
        email: normalizedEmail,
        phone: '',
        picture: normalizedPicture,
        requires_password_setup: true,
        requires_phone_validation: true,
      },
    });
  } catch (error) {
    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'A user with this email/student ID already exists.',
      });
    }

    console.error('Google auth controller error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error while processing Google auth.',
    });
  }
};

module.exports = { google };
