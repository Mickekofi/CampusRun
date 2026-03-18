const pool = require('../../config/db');

// Validation Functions
const validateInput = (studentId, email, phoneNumber) => {
  if ((!studentId && !email) || !phoneNumber) {
    return {
      valid: false,
      message: 'student_id or email, and phone are required.',
    };
  }
  return { valid: true };
};

const validatePhoneFormat = (phoneNumber) => {
  if (!/^\+?[0-9]{10,15}$/.test(phoneNumber)) {
    return {
      valid: false,
      message: 'Phone number format is invalid.',
    };
  }
  return { valid: true };
};

// Data Normalization Functions
const normalizeInputs = (studentId, email, phoneNumber) => {
  return {
    normalizedPhone: String(phoneNumber).trim(),
    normalizedEmail: email ? String(email).trim().toLowerCase() : null,
    normalizedStudentId: studentId ? String(studentId).trim() : null,
  };
};

// Database Functions
const checkPhoneExists = async (db, phoneNumber) => {
  const [phoneRows] = await db.query(
    'SELECT id FROM users WHERE phone = ? LIMIT 1',
    [phoneNumber]
  );
  return phoneRows.length > 0;
};

const updateUserPhone = async (db, phoneNumber, email, studentId) => {
  const whereClause = email ? 'email = ?' : 'student_id = ?';
  const whereValue = email || studentId;

  const [result] = await db.query(
    `UPDATE users SET phone = ? WHERE ${whereClause} LIMIT 1`,
    [phoneNumber, whereValue]
  );
  return result;
};

// Main Controller
const phone = async (req, res) => {
  const { student_id: studentId, email, phone: phoneNumber } = req.body || {};

  // Validate input
  const inputValidation = validateInput(studentId, email, phoneNumber);
  if (!inputValidation.valid) {
    return res.status(400).json({ success: false, message: inputValidation.message });
  }

  // Normalize inputs
  const { normalizedPhone, normalizedEmail, normalizedStudentId } = normalizeInputs(
    studentId,
    email,
    phoneNumber
  );

  // Validate phone format
  const formatValidation = validatePhoneFormat(normalizedPhone);
  if (!formatValidation.valid) {
    return res.status(400).json({ success: false, message: formatValidation.message });
  }

  try {
    const db = pool.promise();

    // Check if phone already exists
    const phoneExists = await checkPhoneExists(db, normalizedPhone);
    if (phoneExists) {
      return res.status(409).json({
        success: false,
        message: 'This phone number is already linked to another account.',
      });
    }

    // Update user phone
    const result = await updateUserPhone(db, normalizedPhone, normalizedEmail, normalizedStudentId);
    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found for phone validation.',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Phone validated and updated successfully.',
    });
  } catch (error) {
    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'Phone already exists.',
      });
    }

    console.error('Phone controller error:', error);
    return res.status(500).json({
      success: false,
      message: 'Internal server error while validating phone.',
    });
  }
};

module.exports = { phone };
