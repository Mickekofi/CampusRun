const bcrypt = require('bcryptjs');
const pool = require('../config/db');

const MAX_FAILED_ATTEMPTS = Number(process.env.LOGIN_MAX_FAILED_ATTEMPTS || 5);
const ATTEMPT_WINDOW_MINUTES = Number(process.env.LOGIN_ATTEMPT_WINDOW_MINUTES || 15);
const LOCKOUT_MINUTES = Number(process.env.LOGIN_LOCKOUT_MINUTES || 15);
const BCRYPT_HASH_REGEX = /^\$2[aby]\$\d{2}\$[./A-Za-z0-9]{53}$/;

const buildLoginReference = () => {
  return `LGA-${Date.now()}-${Math.random().toString(36).slice(2, 10).toUpperCase()}`;
};

const getClientIp = (req) => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || null;
};

const writeLoginAudit = async ({
  actorType = 'unknown',
  actorId = null,
  identifier,
  loginStatus,
  failureReason = null,
  ipAddress = null,
  userAgent = null,
}) => {
  try {
    const db = pool.promise();
    await db.query(
      'INSERT INTO login_audit_logs (login_reference, actor_type, actor_id, identifier, login_status, failure_reason, ip_address, user_agent) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        buildLoginReference(),
        actorType,
        actorId,
        identifier,
        loginStatus,
        failureReason,
        ipAddress,
        userAgent,
      ]
    );
  } catch (auditError) {
    console.error('login audit write error:', auditError.message);
  }
};

const getLockoutStatus = async ({ identifier, ipAddress }) => {
  try {
    const db = pool.promise();

    const [rows] = await db.query(
      `SELECT COUNT(*) AS failed_count,
              MAX(created_at) AS last_failed_at
         FROM login_audit_logs
        WHERE login_status = 'failed'
          AND created_at >= (NOW() - INTERVAL ? MINUTE)
          AND (
                identifier = ?
                OR (? IS NOT NULL AND ip_address = ?)
              )`,
      [ATTEMPT_WINDOW_MINUTES, identifier, ipAddress, ipAddress]
    );

    const failedCount = Number(rows?.[0]?.failed_count || 0);
    const lastFailedAt = rows?.[0]?.last_failed_at
      ? new Date(rows[0].last_failed_at)
      : null;

    if (failedCount < MAX_FAILED_ATTEMPTS || !lastFailedAt) {
      return { locked: false, retryAfterSeconds: 0, failedCount };
    }

    const lockoutUntil = new Date(lastFailedAt.getTime() + LOCKOUT_MINUTES * 60 * 1000);
    const now = new Date();

    if (lockoutUntil <= now) {
      return { locked: false, retryAfterSeconds: 0, failedCount };
    }

    const retryAfterSeconds = Math.ceil((lockoutUntil.getTime() - now.getTime()) / 1000);
    return { locked: true, retryAfterSeconds, failedCount };
  } catch (error) {
    console.error('lockout status check error:', error.message);
    return { locked: false, retryAfterSeconds: 0, failedCount: 0 };
  }
};

const hasValidPasswordHash = (passwordHash) => {
  if (passwordHash === null || passwordHash === undefined) return false;
  return BCRYPT_HASH_REGEX.test(String(passwordHash));
};

const isPhoneVerified = (phone) => {
  if (phone === null || phone === undefined) return false;
  const normalized = String(phone).trim();
  if (!normalized) return false;
  if (normalized.startsWith('TMP')) return false;
  return /^\+?[0-9]{10,15}$/.test(normalized);
};

const loginWithRoleAccess = async (req, res) => {
  const { identifier, password } = req.body || {};
  const identifierForAudit = String(identifier || '').trim().toLowerCase() || 'unknown';
  const ipAddress = getClientIp(req);
  const userAgent = req.get('user-agent') || null;

  if (!identifier || !password) {
    await writeLoginAudit({
      actorType: 'unknown',
      actorId: null,
      identifier: identifierForAudit,
      loginStatus: 'failed',
      failureReason: 'Missing identifier or password',
      ipAddress,
      userAgent,
    });

    return res.status(400).json({
      success: false,
      message: 'identifier and password are required.',
    });
  }

  const normalizedIdentifier = String(identifier).trim().toLowerCase();

  try {
    const lockout = await getLockoutStatus({
      identifier: normalizedIdentifier,
      ipAddress,
    });

    if (lockout.locked) {
      await writeLoginAudit({
        actorType: 'unknown',
        actorId: null,
        identifier: normalizedIdentifier,
        loginStatus: 'failed',
        failureReason: `Temporarily locked due to repeated failed attempts (${lockout.failedCount} failures)`,
        ipAddress,
        userAgent,
      });

      return res.status(429).json({
        success: false,
        message: `Too many failed attempts. Try again in ${lockout.retryAfterSeconds} seconds.`,
        retry_after_seconds: lockout.retryAfterSeconds,
      });
    }

    const db = pool.promise();

    const [adminRows] = await db.query(
      'SELECT id, full_name, email, phone, password_hash, role, account_status FROM admins WHERE LOWER(email) = ? OR phone = ? LIMIT 1',
      [normalizedIdentifier, normalizedIdentifier]
    );

    if (adminRows.length > 0) {
      const admin = adminRows[0];

      if (admin.account_status !== 'active') {
        await writeLoginAudit({
          actorType: 'admin',
          actorId: admin.id,
          identifier: normalizedIdentifier,
          loginStatus: 'failed',
          failureReason: 'Admin account not active',
          ipAddress,
          userAgent,
        });

        return res.status(403).json({
          success: false,
          message: 'Admin account is not active.',
        });
      }

      const isPasswordValid = await bcrypt.compare(
        String(password),
        admin.password_hash
      );

      if (!isPasswordValid) {
        await writeLoginAudit({
          actorType: 'admin',
          actorId: admin.id,
          identifier: normalizedIdentifier,
          loginStatus: 'failed',
          failureReason: 'Invalid admin password',
          ipAddress,
          userAgent,
        });

        return res.status(401).json({
          success: false,
          message: 'Invalid credentials.',
        });
      }

      await writeLoginAudit({
        actorType: 'admin',
        actorId: admin.id,
        identifier: normalizedIdentifier,
        loginStatus: 'successful',
        ipAddress,
        userAgent,
      });

      return res.status(200).json({
        success: true,
        message: 'Admin login successful.',
        role: 'admin',
        next_step: 'dashboard',
        data: {
          id: admin.id,
          full_name: admin.full_name,
          email: admin.email,
          phone: admin.phone,
          admin_role: admin.role,
          account_status: admin.account_status,
        },
      });
    }

    const [userRows] = await db.query(
      'SELECT id, student_id, full_name, email, profile_picture, phone, password_hash, account_status FROM users WHERE LOWER(email) = ? OR student_id = ? OR phone = ? LIMIT 1',
      [normalizedIdentifier, normalizedIdentifier, normalizedIdentifier]
    );

    if (userRows.length === 0) {
      await writeLoginAudit({
        actorType: 'unknown',
        actorId: null,
        identifier: normalizedIdentifier,
        loginStatus: 'failed',
        failureReason: 'User does not exist',
        ipAddress,
        userAgent,
      });

      return res.status(404).json({
        success: false,
        message: 'User does not exist.',
      });
    }

    const user = userRows[0];

    if (user.account_status !== 'active') {
      await writeLoginAudit({
        actorType: 'user',
        actorId: user.id,
        identifier: normalizedIdentifier,
        loginStatus: 'failed',
        failureReason: 'User account not active',
        ipAddress,
        userAgent,
      });

      return res.status(403).json({
        success: false,
        message: 'User account is not active.',
      });
    }

    if (!hasValidPasswordHash(user.password_hash)) {
      await writeLoginAudit({
        actorType: 'user',
        actorId: user.id,
        identifier: normalizedIdentifier,
        loginStatus: 'failed',
        failureReason: 'Password setup required for Google-linked account',
        ipAddress,
        userAgent,
      });

      return res.status(403).json({
        success: false,
        message: 'Password setup required. Please set your account password first.',
        requires_password_setup: true,
        role: 'user',
        next_step: 'set_password',
        data: {
          id: user.id,
          student_id: user.student_id,
          full_name: user.full_name,
          email: user.email,
          phone: user.phone,
          picture: user.profile_picture,
          requires_phone_validation:
            !(user.phone && !String(user.phone).startsWith('TMP')),
        },
      });
    }

    const isPasswordValid = await bcrypt.compare(
      String(password),
      user.password_hash
    );

    if (!isPasswordValid) {
      await writeLoginAudit({
        actorType: 'user',
        actorId: user.id,
        identifier: normalizedIdentifier,
        loginStatus: 'failed',
        failureReason: 'Invalid user password',
        ipAddress,
        userAgent,
      });

      return res.status(401).json({
        success: false,
        message: 'Invalid credentials.',
      });
    }

    await writeLoginAudit({
      actorType: 'user',
      actorId: user.id,
      identifier: normalizedIdentifier,
      loginStatus: 'successful',
      ipAddress,
      userAgent,
    });

    return res.status(200).json({
      success: true,
      message: 'User login successful.',
      role: 'user',
      next_step: isPhoneVerified(user.phone) ? 'dashboard' : 'validate_phone',
      data: {
        id: user.id,
        student_id: user.student_id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone,
        picture: user.profile_picture,
        account_status: user.account_status,
        requires_phone_validation: !isPhoneVerified(user.phone),
        requires_password_setup: false,
      },
    });
  } catch (error) {
    console.error('loginWithRoleAccess error:', error);

    await writeLoginAudit({
      actorType: 'unknown',
      actorId: null,
      identifier: normalizedIdentifier,
      loginStatus: 'failed',
      failureReason: 'Internal server error during login',
      ipAddress,
      userAgent,
    });

    return res.status(500).json({
      success: false,
      message: 'Internal server error during login.',
    });
  }
};

module.exports = { loginWithRoleAccess };
