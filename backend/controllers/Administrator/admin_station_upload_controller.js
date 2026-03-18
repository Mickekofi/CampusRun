const pool = require('../../config/db');

// ============================================================================
// SHARED HELPERS
// ============================================================================

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

const writeAdminLog = async (
  db,
  { adminId, actionType, targetTable, targetId = null, description, ipAddress }
) => {
  await db.query(
    'INSERT INTO admin_logs (admin_id, action_type, target_table, target_id, description, ip_address) VALUES (?, ?, ?, ?, ?, ?)',
    [adminId, actionType, targetTable, targetId, description, ipAddress]
  );
};













const ensureAdminStationExtensionTables = async (db) => {
  await db.query(
    `CREATE TABLE IF NOT EXISTS transport_prices (
      id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      from_station_id BIGINT UNSIGNED NOT NULL,
      to_station_id BIGINT UNSIGNED NOT NULL,
      price_cedis DECIMAL(10,2) NOT NULL,
      allocated_time INT UNSIGNED NULL,
      description VARCHAR(255) NULL,
      status ENUM('active','inactive') NOT NULL DEFAULT 'active',
      created_by BIGINT UNSIGNED NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY uniq_route_price (from_station_id, to_station_id),
      INDEX idx_from_station (from_station_id),
      INDEX idx_to_station (to_station_id),
      FOREIGN KEY (from_station_id) REFERENCES stations(id) ON DELETE CASCADE ON UPDATE CASCADE,
      FOREIGN KEY (created_by) REFERENCES admins(id) ON DELETE RESTRICT ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
  );

  // THE FIX: Safely attempt to add the column for legacy tables, silently ignore if it already exists.
  try {
    await db.query(
      `ALTER TABLE transport_prices ADD COLUMN allocated_time INT UNSIGNED NULL AFTER price_cedis`
    );
  } catch (error) {
    // If the error is anything OTHER than "Duplicate Column", we log it.
    if (error.code !== 'ER_DUP_FIELDNAME') {
      console.error('Migration error for transport_prices:', error.message);
    }
  }

  await db.query(
    `CREATE TABLE IF NOT EXISTS banned_zones (
      id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      zone_name VARCHAR(150) NOT NULL,
      latitude DECIMAL(10,8) NOT NULL,
      longitude DECIMAL(11,8) NOT NULL,
      radius_meters INT UNSIGNED NOT NULL DEFAULT 50,
      reason VARCHAR(255) NULL,
      status ENUM('active','inactive') NOT NULL DEFAULT 'active',
      created_by BIGINT UNSIGNED NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_zone_status (status),
      INDEX idx_zone_latlng (latitude, longitude),
      FOREIGN KEY (created_by) REFERENCES admins(id) ON DELETE RESTRICT ON UPDATE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
  );
};









const assertStationExists = async (db, stationId) => {
  const id = Number(stationId);
  if (!Number.isFinite(id) || id <= 0) {
    throw new Error('Station ID must be a valid positive number.');
  }

  const [rows] = await db.query('SELECT id FROM stations WHERE id = ? LIMIT 1', [
    id,
  ]);

  if (rows.length === 0) {
    throw new Error(`Station with id ${id} does not exist.`);
  }
};

// ============================================================================
// SECTION A/B/C: STATIONS CRUD
// ============================================================================

const listStations = async (_req, res) => {
  try {
    const db = pool.promise();
    const [rows] = await db.query(
      `SELECT id, station_name, station_type, latitude, longitude, radius_meters, base_price, status, created_by, created_at, updated_at
       FROM stations
       ORDER BY id DESC`
    );

    return res.status(200).json({ success: true, data: rows });
  } catch (error) {
    console.error('listStations error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch stations right now.',
    });
  }
};

const createStation = async (req, res) => {
  const {
    station_name: stationName,
    station_type: stationType,
    latitude,
    longitude,
    radius_meters: radiusMeters,
    base_price: basePrice,
    status,
    admin_id: explicitAdminId,
  } = req.body || {};

  if (!stationName || !latitude || !longitude) {
    return res.status(400).json({
      success: false,
      message: 'station_name, latitude, and longitude are required.',
    });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [result] = await db.query(
      `INSERT INTO stations
       (station_name, station_type, latitude, longitude, radius_meters, base_price, status, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        String(stationName).trim(),
        stationType ? String(stationType) : 'both',
        Number(latitude),
        Number(longitude),
        Number.isFinite(Number(radiusMeters)) ? Number(radiusMeters) : 50,
        Number.isFinite(Number(basePrice)) ? Number(basePrice) : 0,
        status ? String(status) : 'active',
        adminId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'station_create',
      targetTable: 'stations',
      targetId: result.insertId,
      description: `Created station ${String(stationName).trim()}`,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Station created successfully.',
      data: { id: result.insertId },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to create station.',
    });
  }
};

const updateStation = async (req, res) => {
  const stationId = Number(req.params.stationId);
  const {
    station_name: stationName,
    station_type: stationType,
    latitude,
    longitude,
    radius_meters: radiusMeters,
    base_price: basePrice,
    status,
    admin_id: explicitAdminId,
  } = req.body || {};

  if (!Number.isFinite(stationId) || stationId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid station ID.' });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [existingRows] = await db.query(
      'SELECT id FROM stations WHERE id = ? LIMIT 1',
      [stationId]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Station not found.' });
    }

    await db.query(
      `UPDATE stations
       SET station_name = COALESCE(?, station_name),
           station_type = COALESCE(?, station_type),
           latitude = COALESCE(?, latitude),
           longitude = COALESCE(?, longitude),
           radius_meters = COALESCE(?, radius_meters),
           base_price = COALESCE(?, base_price),
           status = COALESCE(?, status)
       WHERE id = ?`,
      [
        stationName ? String(stationName).trim() : null,
        stationType ? String(stationType) : null,
        Number.isFinite(Number(latitude)) ? Number(latitude) : null,
        Number.isFinite(Number(longitude)) ? Number(longitude) : null,
        Number.isFinite(Number(radiusMeters)) ? Number(radiusMeters) : null,
        Number.isFinite(Number(basePrice)) ? Number(basePrice) : null,
        status ? String(status) : null,
        stationId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'station_update',
      targetTable: 'stations',
      targetId: stationId,
      description: `Updated station ID ${stationId}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Station updated successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to update station.',
    });
  }
};

const deleteStation = async (req, res) => {
  const stationId = Number(req.params.stationId);
  const explicitAdminId = req.body?.admin_id ?? req.headers['x-admin-id'];

  if (!Number.isFinite(stationId) || stationId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid station ID.' });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [existingRows] = await db.query(
      'SELECT station_name FROM stations WHERE id = ? LIMIT 1',
      [stationId]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Station not found.' });
    }

    await db.query('DELETE FROM stations WHERE id = ?', [stationId]);

    await writeAdminLog(db, {
      adminId,
      actionType: 'station_delete',
      targetTable: 'stations',
      targetId: stationId,
      description: `Deleted station ${existingRows[0].station_name || stationId}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Station deleted successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to delete station.',
    });
  }
};

// ============================================================================
// LEGACY PAYMENT UPLOAD (kept for compatibility)
// ============================================================================

const createPayment = async (req, res) => {
  const {
    user_id: userId,
    ride_id: rideId,
    amount,
    payment_method: paymentMethod,
    transaction_type: transactionType,
    payment_status: paymentStatus,
    external_reference: externalReference,
    admin_id: explicitAdminId,
  } = req.body || {};

  if (!userId || !amount || !paymentMethod || !transactionType) {
    return res.status(400).json({
      success: false,
      message:
        'user_id, amount, payment_method, and transaction_type are required.',
    });
  }

  try {
    const db = pool.promise();
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const paymentReference = `PAY-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 8)
      .toUpperCase()}`;

    const [result] = await db.query(
      `INSERT INTO payments
       (payment_reference, user_id, ride_id, amount, payment_method, transaction_type, payment_status, external_reference, processed_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        paymentReference,
        Number(userId),
        Number.isFinite(Number(rideId)) ? Number(rideId) : null,
        Number(amount),
        String(paymentMethod),
        String(transactionType),
        paymentStatus ? String(paymentStatus) : 'pending',
        externalReference ? String(externalReference) : null,
        adminId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'payment_create',
      targetTable: 'payments',
      targetId: result.insertId,
      description: `Created payment ${paymentReference} for user ${userId}`,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Payment record created successfully.',
      data: { id: result.insertId, payment_reference: paymentReference },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to create payment record.',
    });
  }
};

// ============================================================================
// SECTION D: ROUTE PRICES
// ============================================================================

const listTransportPrices = async (_req, res) => {
  try {
    const db = pool.promise();
    await ensureAdminStationExtensionTables(db);

    const [rows] = await db.query(
      `SELECT
         tp.id,
         tp.from_station_id,
         tp.to_station_id,
         tp.price_cedis,
         tp.allocated_time,
         tp.description,
         tp.status,
         tp.created_at,
         sf.station_name AS from_station_name,
         st.station_name AS to_station_name
       FROM transport_prices tp
       INNER JOIN stations sf ON sf.id = tp.from_station_id
       INNER JOIN stations st ON st.id = tp.to_station_id
       ORDER BY tp.id DESC`
    );

    return res.status(200).json({ success: true, data: rows });
  } catch (error) {
    console.error('listTransportPrices error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch transport prices right now.',
    });
  }
};

const createTransportPrice = async (req, res) => {
  const {
    from_station_id: fromStationId,
    to_station_id: toStationId,
    price_cedis: priceCedis,
    allocated_time: allocatedTime,
    description,
    status,
    admin_id: explicitAdminId,
  } = req.body || {};

  if (!fromStationId || !toStationId || priceCedis === undefined) {
    return res.status(400).json({
      success: false,
      message: 'from_station_id, to_station_id, and price_cedis are required.',
    });
  }

  const parsedPrice = Number(priceCedis);
  if (!Number.isFinite(parsedPrice) || parsedPrice < 0) {
    return res.status(400).json({
      success: false,
      message: 'price_cedis must be a valid non-negative number.',
    });
  }

  const parsedAllocatedTime =
    allocatedTime === null ||
    allocatedTime === undefined ||
    String(allocatedTime).trim() === ''
      ? null
      : Number(allocatedTime);

  if (
    parsedAllocatedTime !== null &&
    (!Number.isFinite(parsedAllocatedTime) || parsedAllocatedTime < 0)
  ) {
    return res.status(400).json({
      success: false,
      message: 'allocated_time must be a valid non-negative number.',
    });
  }

  if (Number(fromStationId) === Number(toStationId)) {
    return res.status(400).json({
      success: false,
      message: 'from_station_id and to_station_id cannot be the same.',
    });
  }

  try {
    const db = pool.promise();
    await ensureAdminStationExtensionTables(db);
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    await assertStationExists(db, fromStationId);
    await assertStationExists(db, toStationId);

    const [existingRows] = await db.query(
      'SELECT id FROM transport_prices WHERE from_station_id = ? AND to_station_id = ? LIMIT 1',
      [Number(fromStationId), Number(toStationId)]
    );

    if (existingRows.length > 0) {
      await db.query(
        `UPDATE transport_prices
         SET price_cedis = ?,
             allocated_time = ?,
             description = ?,
             status = ?,
             created_by = ?
         WHERE id = ?`,
        [
          parsedPrice,
          parsedAllocatedTime === null
            ? null
            : Math.trunc(parsedAllocatedTime),
          description ? String(description).trim() : null,
          status ? String(status) : 'active',
          adminId,
          existingRows[0].id,
        ]
      );

      await writeAdminLog(db, {
        adminId,
        actionType: 'transport_price_update',
        targetTable: 'transport_prices',
        targetId: existingRows[0].id,
        description: `Updated route price ${fromStationId} -> ${toStationId} to ${parsedPrice}`,
        ipAddress,
      });

      return res.status(200).json({
        success: true,
        message: 'Transport price updated successfully.',
      });
    }

    const [result] = await db.query(
      `INSERT INTO transport_prices
       (from_station_id, to_station_id, price_cedis, allocated_time, description, status, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        Number(fromStationId),
        Number(toStationId),
        parsedPrice,
        parsedAllocatedTime === null
          ? null
          : Math.trunc(parsedAllocatedTime),
        description ? String(description).trim() : null,
        status ? String(status) : 'active',
        adminId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'transport_price_create',
      targetTable: 'transport_prices',
      targetId: result.insertId,
      description: `Created route price ${fromStationId} -> ${toStationId} at ${parsedPrice}`,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Transport price created successfully.',
      data: { id: result.insertId },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to save transport price.',
    });
  }
};

const deleteTransportPrice = async (req, res) => {
  const priceId = Number(req.params.priceId);
  const explicitAdminId = req.body?.admin_id ?? req.headers['x-admin-id'];

  if (!Number.isFinite(priceId) || priceId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid price ID.' });
  }

  try {
    const db = pool.promise();
    await ensureAdminStationExtensionTables(db);
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [existingRows] = await db.query(
      'SELECT id, from_station_id, to_station_id FROM transport_prices WHERE id = ? LIMIT 1',
      [priceId]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Transport price not found.',
      });
    }

    await db.query('DELETE FROM transport_prices WHERE id = ?', [priceId]);

    await writeAdminLog(db, {
      adminId,
      actionType: 'transport_price_delete',
      targetTable: 'transport_prices',
      targetId: priceId,
      description: `Deleted route price ${existingRows[0].from_station_id} -> ${existingRows[0].to_station_id}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Transport price deleted successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to delete transport price.',
    });
  }
};

// ============================================================================
// SECTION E/F: BANNED ZONES
// ============================================================================

const listBannedZones = async (_req, res) => {
  try {
    const db = pool.promise();
    await ensureAdminStationExtensionTables(db);

    const [rows] = await db.query(
      `SELECT id, zone_name, latitude, longitude, radius_meters, reason, status, created_by, created_at, updated_at
       FROM banned_zones
       ORDER BY id DESC`
    );

    return res.status(200).json({ success: true, data: rows });
  } catch (error) {
    console.error('listBannedZones error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to fetch banned zones right now.',
    });
  }
};

const createBannedZone = async (req, res) => {
  const {
    zone_name: zoneName,
    latitude,
    longitude,
    radius_meters: radiusMeters,
    reason,
    status,
    admin_id: explicitAdminId,
  } = req.body || {};

  if (!zoneName || latitude === undefined || longitude === undefined) {
    return res.status(400).json({
      success: false,
      message: 'zone_name, latitude, and longitude are required.',
    });
  }

  try {
    const db = pool.promise();
    await ensureAdminStationExtensionTables(db);
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [result] = await db.query(
      `INSERT INTO banned_zones
       (zone_name, latitude, longitude, radius_meters, reason, status, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        String(zoneName).trim(),
        Number(latitude),
        Number(longitude),
        Number.isFinite(Number(radiusMeters)) ? Number(radiusMeters) : 50,
        reason ? String(reason).trim() : null,
        status ? String(status) : 'active',
        adminId,
      ]
    );

    await writeAdminLog(db, {
      adminId,
      actionType: 'banned_zone_create',
      targetTable: 'banned_zones',
      targetId: result.insertId,
      description: `Created banned zone ${String(zoneName).trim()}`,
      ipAddress,
    });

    return res.status(201).json({
      success: true,
      message: 'Banned zone created successfully.',
      data: { id: result.insertId },
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to create banned zone.',
    });
  }
};

const deleteBannedZone = async (req, res) => {
  const zoneId = Number(req.params.zoneId);
  const explicitAdminId = req.body?.admin_id ?? req.headers['x-admin-id'];

  if (!Number.isFinite(zoneId) || zoneId <= 0) {
    return res.status(400).json({ success: false, message: 'Invalid zone ID.' });
  }

  try {
    const db = pool.promise();
    await ensureAdminStationExtensionTables(db);
    const adminId = await resolveAdminId(db, req, explicitAdminId);
    const ipAddress = getClientIp(req);

    const [existingRows] = await db.query(
      'SELECT id, zone_name FROM banned_zones WHERE id = ? LIMIT 1',
      [zoneId]
    );

    if (existingRows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Banned zone not found.',
      });
    }

    await db.query('DELETE FROM banned_zones WHERE id = ?', [zoneId]);

    await writeAdminLog(db, {
      adminId,
      actionType: 'banned_zone_delete',
      targetTable: 'banned_zones',
      targetId: zoneId,
      description: `Deleted banned zone ${existingRows[0].zone_name}`,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Banned zone deleted successfully.',
    });
  } catch (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'Unable to delete banned zone.',
    });
  }
};

module.exports = {
  listStations,
  createStation,
  updateStation,
  deleteStation,
  createPayment,
  listTransportPrices,
  createTransportPrice,
  deleteTransportPrice,
  listBannedZones,
  createBannedZone,
  deleteBannedZone,
};