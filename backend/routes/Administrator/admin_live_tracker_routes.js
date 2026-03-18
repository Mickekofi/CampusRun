/*
 * admin_live_tracker_routes.js
 * -----------------------------------------------------------------------
 * Defines all HTTP routes for the Admin Live Tracker feature and maps
 * each route to its controller handler.
 *
 * Mount point in server.js:
 *   app.use('/api/admin_live_tracker_routes', adminLiveTrackerRoutes);
 *
 * Full endpoint list:
 *   GET  /api/admin_live_tracker_routes/active-riders
 *         → Returns all riders with a fresh location (in ride mode).
 *           Used by the admin map to display live markers.
 *
 *   POST /api/admin_live_tracker_routes/location
 *         → Accepts a GPS ping from the user_ridemode_screen.
 *           Upserts user_location_latest and appends to the trail table.
 *
 *   GET  /api/admin_live_tracker_routes/rider/:userId/trail
 *         → Returns the recent position history for one rider.
 *           Used to draw the polyline path on the admin map.
 * -----------------------------------------------------------------------
 */

const express = require('express');
const router  = express.Router();

const {
  getActiveRiders,
  upsertRiderLocation,
  getRiderTrail,
} = require('../../controllers/Administrator/admin_live_tracker_controller');

// ── Route definitions ─────────────────────────────────────────────────

// Fetch all currently active riders (admin map polling)
router.get('/active-riders', getActiveRiders);

// Receive a live GPS ping from a rider (called by user app)
router.post('/location', upsertRiderLocation);

// Fetch location history for a specific rider (trail polyline)
router.get('/rider/:userId/trail', getRiderTrail);

module.exports = router;
