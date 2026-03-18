const pool = require('../../config/db');

const USER_ACCOUNT_STATUSES = new Set(['active', 'suspended', 'banned']);

const LEVEL_MAP = {
  '523': 'Level 400',
  '524': 'Level 300',
  '525': 'Level 200',
  '526': 'Level 100',
};

const mapStudentLevel = (studentId) => {
  const normalized = String(studentId || '').trim();
  const key = normalized.slice(0, 3);
  return LEVEL_MAP[key] || 'Other';
};

const getClientIp = (req) => {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || null;
};

const resolveAdminId = async (db, req, explicitAdminId) => {
  const adminIdRaw =
    explicitAdminId ?? req.body?.admin_id ?? req.headers['x-admin-id'];
  const adminId = Number(adminIdRaw);

  if (!Number.isFinite(adminId) || adminId <= 0) {
    throw new Error('A valid active admin_id is required.');
  }

  const [rows] = await db.query(
    'SELECT id FROM admins WHERE id = ? AND account_status = ? LIMIT 1',
    [adminId, 'active']
  );

  if (rows.length === 0) {
    throw new Error('Admin not found or not active.');
  }

  return adminId;
};

const writeAdminLog = async (db, {
  adminId,
  actionType,
  targetTable,
  targetId = null,
  description,
  ipAddress,
}) => {
  await db.query(
    'INSERT INTO admin_logs (admin_id, action_type, target_table, target_id, description, ip_address) VALUES (?, ?, ?, ?, ?, ?)',
    [adminId, actionType, targetTable, targetId, description, ipAddress]
  );
};

const getUserMonitorStats = async (_req, res) => {
  try {
    const db = pool.promise();

    const [[totals]] = await db.query(
      `SELECT
         COUNT(*) AS total_students,
         SUM(CASE WHEN account_status = 'active' THEN 1 ELSE 0 END) AS active_students,
         SUM(CASE WHEN account_status = 'suspended' THEN 1 ELSE 0 END) AS suspended_students,
         SUM(CASE WHEN account_status = 'banned' THEN 1 ELSE 0 END) AS banned_students
       FROM users`
    );

    const [userRows] = await db.query(
      'SELECT id, student_id, full_name, email, phone, account_status FROM users ORDER BY created_at DESC'
    );

    const levelStats = {
      'Level 400': 0,
      'Level 300': 0,
      'Level 200': 0,
      'Level 100': 0,
      Other: 0,
    };

    userRows.forEach((user) => {
      const level = mapStudentLevel(user.student_id);
      levelStats[level] = (levelStats[level] || 0) + 1;
    });

    const levelBreakdown = Object.entries(levelStats).map(([level, count]) => ({
      level,
      count,
    }));

    return res.status(200).json({
      success: true,
      data: {
        totals,
        level_breakdown: levelBreakdown,
        pie_series: levelBreakdown.map((entry) => ({
          label: entry.level,
          value: entry.count,
        })),
        users: userRows,
      },
    });
  } catch (error) {
    console.error('getUserMonitorStats error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch user monitor statistics.',
    });
  }
};

const listUsers = async (req, res) => {
  const statusFilter = (req.query.status || 'all').toString().trim().toLowerCase();
  const search = (req.query.q || '').toString().trim();
  const pageRaw = Number(req.query.page || 1);
  const limitRaw = Number(req.query.limit || 12);

  const page = Number.isFinite(pageRaw) && pageRaw > 0 ? Math.floor(pageRaw) : 1;
  const limit = Number.isFinite(limitRaw) && limitRaw > 0
    ? Math.min(Math.floor(limitRaw), 100)
    : 12;
  const offset = (page - 1) * limit;

  if (statusFilter !== 'all' && !USER_ACCOUNT_STATUSES.has(statusFilter)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid user status filter.',
    });
  }

  try {
    const db = pool.promise();

    const where = [];
    const params = [];

    if (statusFilter !== 'all') {
      where.push('u.account_status = ?');
      params.push(statusFilter);
    }

    if (search) {
      where.push('(u.full_name LIKE ? OR u.student_id LIKE ?)');
      params.push(`%${search}%`, `%${search}%`);
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';

    const [[countRow]] = await db.query(
      `SELECT COUNT(*) AS total_users
       FROM users u
       ${whereClause}`,
      params
    );

    const totalUsers = Number(countRow?.total_users || 0);
    const totalPages = Math.max(1, Math.ceil(totalUsers / limit));

    let rows;
    try {
      const [fullRows] = await db.query(
        `SELECT
           u.id,
           u.student_id,
           u.full_name,
           u.email,
           u.profile_picture,
           u.phone,
           u.wallet_balance,
           u.account_status,
           u.created_at,
           u.updated_at,
           (
             SELECT COUNT(*)
             FROM rides r
             WHERE r.user_id = u.id
           ) AS total_rides
         FROM users u
         ${whereClause}
         ORDER BY u.created_at DESC
         LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );
      rows = fullRows;
    } catch (queryError) {
      const recoverable = queryError && (
        queryError.code === 'ER_BAD_FIELD_ERROR' ||
        queryError.code === 'ER_NO_SUCH_TABLE'
      );

      if (!recoverable) {
        throw queryError;
      }

      const [fallbackRows] = await db.query(
        `SELECT
           u.id,
           u.student_id,
           u.full_name,
           u.email,
           u.phone,
           u.account_status,
           u.created_at,
           0 AS total_rides
         FROM users u
         ${whereClause}
         ORDER BY u.created_at DESC
         LIMIT ? OFFSET ?`,
        [...params, limit, offset]
      );

      rows = fallbackRows;
    }

    return res.status(200).json({
      success: true,
      data: {
        rows,
        pagination: {
          page,
          limit,
          total_users: totalUsers,
          total_pages: totalPages,
        },
      },
    });
  } catch (error) {
    console.error('listUsers error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch users right now.',
    });
  }
};

const updateUserStatus = async (req, res) => {
  const userId = Number(req.params.userId);
  const { status, admin_id: explicitAdminId } = req.body || {};

  if (!Number.isFinite(userId) || userId <= 0) {
    return res.status(400).json({
      success: false,
      message: 'Invalid user ID.',
    });
  }

  if (!status || !USER_ACCOUNT_STATUSES.has(String(status))) {
    return res.status(400).json({
      success: false,
      message: 'Invalid user account status.',
    });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [result] = await db.query(
      'UPDATE users SET account_status = ? WHERE id = ?',
      [String(status), userId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    await writeAdminLog(db, {
      adminId,
      actionType: 'user_status_update',
      targetTable: 'users',
      targetId: userId,
      description: `Set user ${userId} account_status to ${String(status)}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'User status updated successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to update user status.',
    });
  }
};

module.exports = {
  getUserMonitorStats,
  listUsers,
  updateUserStatus,
};
