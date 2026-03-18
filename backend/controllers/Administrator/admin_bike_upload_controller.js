const pool = require('../../config/db');

const BIKE_STATUSES = new Set([
  'available',
  'reserved',
  'active',
  'maintenance',
  'inactive',
  'tampered',
]);

const normalizeStationId = (rawStationId) => {
  if (rawStationId === null || rawStationId === undefined || rawStationId === '') {
    return null;
  }

  const parsed = Number(rawStationId);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new Error('current_station_id must be a valid positive station ID or empty.');
  }

  return parsed;
};

const assertStationExists = async (db, stationId) => {
  if (stationId === null) return;

  const [stationRows] = await db.query(
    'SELECT id FROM stations WHERE id = ? LIMIT 1',
    [stationId]
  );

  if (stationRows.length === 0) {
    throw new Error('Selected station does not exist. Choose a valid station ID.');
  }
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

const listBikes = async (_req, res) => {
  try {
    const db = pool.promise();
    const [rows] = await db.query(
      `SELECT id, bike_code, bike_name, bike_image, battery_level, status, current_station_id, total_rides, last_service_date, created_by, created_at, updated_at
       FROM bikes
       ORDER BY id DESC`
    );

    return res.status(200).json({ success: true, data: rows });
  } catch (error) {
    console.error('listBikes error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch bikes right now.',
    });
  }
};

const createBike = async (req, res) => {
  const {
    bike_code: bikeCode,
    bike_name: bikeName,
    bike_image: bikeImage,
    battery_level: batteryLevel,
    status,
    current_station_id: currentStationId,
    last_service_date: lastServiceDate,
    admin_id: explicitAdminId,
  } = req.body || {};


  if (!bikeCode || !bikeName) {
    return res.status(400).json({
      success: false,
      message: 'bike_code and bike_name are required.',
    });
  }

  if (status && !BIKE_STATUSES.has(String(status))) {
    return res.status(400).json({
      success: false,
      message: 'Invalid bike status.',
    });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);
    const stationId = normalizeStationId(currentStationId);
    if (stationId === null) {
      return res.status(400).json({
        success: false,
        message: 'current_station_id is required.',
      });
    }
    await assertStationExists(db, stationId);

    const [result] = await db.query(
      `INSERT INTO bikes
       (bike_code, bike_name, bike_image, battery_level, status, current_station_id, last_service_date, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        String(bikeCode).trim(),
        String(bikeName).trim(),
        bikeImage ? String(bikeImage).trim() : null,
        Number.isFinite(Number(batteryLevel)) ? Number(batteryLevel) : 100,
        status ? String(status) : 'inactive',
        stationId,
        lastServiceDate || null,
        adminId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'bike_create',
      targetTable: 'bikes',
      targetId: result.insertId,
      description: `Created bike ${String(bikeCode).trim()} (${String(bikeName).trim()})`,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Bike created successfully.',
      data: { id: result.insertId },
    });
  } catch (error) {
    if (error?.code === 'ER_NO_REFERENCED_ROW_2') {
      return res.status(400).json({
        success: false,
        message: 'Invalid station reference. Please choose an existing station ID.',
      });
    }

    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'bike_code must be unique.',
      });
    }

    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to create bike.',
    });
  }
};

const updateBike = async (req, res) => {
  const bikeId = Number(req.params.bikeId);
  const {
    bike_code: bikeCode,
    bike_name: bikeName,
    bike_image: bikeImage,
    battery_level: batteryLevel,
    status,
    current_station_id: currentStationId,
    last_service_date: lastServiceDate,
    admin_id: explicitAdminId,
  } = req.body || {};

  if (!Number.isFinite(bikeId) || bikeId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid bike ID.' });
  }

  if (status && !BIKE_STATUSES.has(String(status))) {
    return res.status(400).json({
      success: false,
      message: 'Invalid bike status.',
    });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);
    const stationId = normalizeStationId(currentStationId);
    if (stationId === null) {
      return res.status(400).json({
        success: false,
        message: 'current_station_id is required.',
      });
    }
    await assertStationExists(db, stationId);

    const [existingRows] = await db.query(
      'SELECT id FROM bikes WHERE id = ? LIMIT 1',
      [bikeId]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Bike not found.' });
    }

    await db.query(
      `UPDATE bikes
       SET bike_code = COALESCE(?, bike_code),
           bike_name = COALESCE(?, bike_name),
           bike_image = COALESCE(?, bike_image),
           battery_level = COALESCE(?, battery_level),
           status = COALESCE(?, status),
           current_station_id = COALESCE(?, current_station_id),
           last_service_date = COALESCE(?, last_service_date)
       WHERE id = ?`,
      [
        bikeCode ? String(bikeCode).trim() : null,
        bikeName ? String(bikeName).trim() : null,
        bikeImage ? String(bikeImage).trim() : null,
        Number.isFinite(Number(batteryLevel)) ? Number(batteryLevel) : null,
        status ? String(status) : null,
        stationId,
        lastServiceDate || null,
        bikeId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'bike_update',
      targetTable: 'bikes',
      targetId: bikeId,
      description: `Updated bike ID ${bikeId}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Bike updated successfully.',
    });
  } catch (error) {
    if (error?.code === 'ER_NO_REFERENCED_ROW_2') {
      return res.status(400).json({
        success: false,
        message: 'Invalid station reference. Please choose an existing station ID.',
      });
    }

    if (error?.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        success: false,
        message: 'bike_code must be unique.',
      });
    }

    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to update bike.',
    });
  }
};

const deleteBike = async (req, res) => {
  const bikeId = Number(req.params.bikeId);
  const explicitAdminId = req.body?.admin_id ?? req.headers['x-admin-id'];

  if (!Number.isFinite(bikeId) || bikeId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid bike ID.' });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [existingRows] = await db.query(
      'SELECT bike_code FROM bikes WHERE id = ? LIMIT 1',
      [bikeId]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Bike not found.' });
    }

    await db.query('DELETE FROM bikes WHERE id = ?', [bikeId]);

    await writeAdminLog(db, {
      adminId,
      actionType: 'bike_delete',
      targetTable: 'bikes',
      targetId: bikeId,
      description: `Deleted bike ${existingRows[0].bike_code || bikeId}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Bike deleted successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to delete bike.',
    });
  }
};

const uploadBikeImage = async (req, res) => {
  try {
    const db = pool.promise();
    await resolveAdminId(db, req, req.body?.admin_id);

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file uploaded.',
      });
    }

    const imagePath = `/uploads/bikes/${req.file.filename}`;

    return res.status(201).json({
      success: true,
      message: 'Bike image uploaded successfully.',
      data: {
        image_path: imagePath,
      },

    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to upload bike image.',
    });
  }
};

module.exports = {
  listBikes,
  createBike,
  updateBike,
  deleteBike,
  uploadBikeImage,
};
