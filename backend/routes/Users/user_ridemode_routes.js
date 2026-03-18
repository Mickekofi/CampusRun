const express = require('express');
const { getActiveRide, syncTelemetry, endRide } = require('../../controllers/Users/user_ridemode_controller');

const router = express.Router();

router.get('/active', getActiveRide);
router.post('/telemetry', syncTelemetry);
router.post('/end', endRide);

module.exports = router;    