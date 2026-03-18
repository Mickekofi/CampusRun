const pool = require('../../config/db');

const BIKE_STATUSES = new Set([
  'available',
  'reserved',
  'active',
  'maintenance',
  'inactive',
  'tampered',
]);

const USER_ACCOUNT_STATUSES = new Set(['active', 'suspended', 'banned']);

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

const getOverview = async (_req, res) => {
  try {
    const db = pool.promise();

    const [[bikeTotals]] = await db.query(
      `SELECT
         COUNT(*) AS total_bikes,
         SUM(CASE WHEN status = 'available' THEN 1 ELSE 0 END) AS available_bikes,
         SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) AS active_bikes,
         SUM(CASE WHEN status = 'reserved' THEN 1 ELSE 0 END) AS reserved_bikes,
         SUM(CASE WHEN status = 'maintenance' THEN 1 ELSE 0 END) AS maintenance_bikes,
         SUM(CASE WHEN status = 'inactive' THEN 1 ELSE 0 END) AS inactive_bikes,
         SUM(CASE WHEN status = 'tampered' THEN 1 ELSE 0 END) AS tampered_bikes
       FROM bikes`
    );

    const [[userTotals]] = await db.query(
      `SELECT
         COUNT(*) AS total_users,
         SUM(CASE WHEN account_status = 'active' THEN 1 ELSE 0 END) AS active_users,
         SUM(CASE WHEN account_status = 'suspended' THEN 1 ELSE 0 END) AS suspended_users,
         SUM(CASE WHEN account_status = 'banned' THEN 1 ELSE 0 END) AS banned_users
       FROM users`
    );

    return res.status(200).json({
      success: true,
      data: {
        bikes: bikeTotals,
        users: userTotals,
      },
    });
  } catch (error) {
    console.error('getOverview error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch bike operations overview.',
    });
  }
};

const listBikes = async (req, res) => {
  const status = (req.query.status || '').toString().trim().toLowerCase();

  if (status && status !== 'all' && !BIKE_STATUSES.has(status)) {
    return res.status(400).json({
      success: false,
      message: 'Invalid bike status filter.',
    });
  }

  try {
    const db = pool.promise();

    let rows;

    try {
      const [fullRows] = status && status !== 'all'
        ? await db.query(
            `SELECT id, bike_code, bike_name, bike_image, battery_level, status, current_station_id, total_rides, updated_at
             FROM bikes
             WHERE status = ?
             ORDER BY id DESC`,
            [status]
          )
        : await db.query(
            `SELECT id, bike_code, bike_name, bike_image, battery_level, status, current_station_id, total_rides, updated_at
             FROM bikes
             ORDER BY id DESC`
          );
      rows = fullRows;
    } catch (queryError) {
      if (queryError && queryError.code === 'ER_BAD_FIELD_ERROR') {
        const [fallbackRows] = status && status !== 'all'
          ? await db.query(
              `SELECT id, bike_code, bike_name, battery_level, status
               FROM bikes
               WHERE status = ?
               ORDER BY id DESC`,
              [status]
            )
          : await db.query(
              `SELECT id, bike_code, bike_name, battery_level, status
               FROM bikes
               ORDER BY id DESC`
            );
        rows = fallbackRows;
      } else {
        throw queryError;
      }
    }

    return res.status(200).json({
      success: true,
      data: rows,
    });
  } catch (error) {
    console.error('listBikes error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch bikes right now.',
    });
  }
};

const updateBikeStatus = async (req, res) => {
  const bikeId = Number(req.params.bikeId);
  const { status, admin_id: explicitAdminId } = req.body || {};

  if (!Number.isFinite(bikeId) || bikeId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid bike ID.' });
  }

  if (!status || !BIKE_STATUSES.has(String(status))) {
    return res.status(400).json({ success: false, message: 'Invalid bike status.' });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [result] = await db.query('UPDATE bikes SET status = ? WHERE id = ?', [
      String(status),
      bikeId,
    ]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Bike not found.' });
    }

    await writeAdminLog(db, {
      adminId,
      actionType: 'bike_status_update',
      targetTable: 'bikes',
      targetId: bikeId,
      description: `Set bike ${bikeId} status to ${String(status)}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Bike status updated successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to update bike status.',
    });
  }
};

const lockBike = async (req, res) => {
  const bikeId = Number(req.params.bikeId);
  const { lock, admin_id: explicitAdminId } = req.body || {};

  if (!Number.isFinite(bikeId) || bikeId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid bike ID.' });
  }

  const lockEnabled = lock === true;
  const mappedStatus = lockEnabled ? 'inactive' : 'available';

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [result] = await db.query('UPDATE bikes SET status = ? WHERE id = ?', [
      mappedStatus,
      bikeId,
    ]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Bike not found.' });
    }

    await writeAdminLog(db, {
      adminId,
      actionType: lockEnabled ? 'bike_lock' : 'bike_unlock',
      targetTable: 'bikes',
      targetId: bikeId,
      description: `${lockEnabled ? 'Locked' : 'Unlocked'} bike ${bikeId}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: lockEnabled
        ? 'Bike locked successfully.'
        : 'Bike unlocked successfully.',
      data: { status: mappedStatus },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to update lock state.',
    });
  }
};

const updateUserAccountStatus = async (req, res) => {
  const userId = Number(req.params.userId);
  const { status, admin_id: explicitAdminId } = req.body || {};

  if (!Number.isFinite(userId) || userId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid user ID.' });
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
      return res.status(404).json({ success: false, message: 'User not found.' });
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
  getOverview,
  listBikes,
  updateBikeStatus,
  lockBike,
  updateUserAccountStatus,
};

