const express = require('express');
const { processQRScanAndStartRide } = require('../../controllers/Users/user_scanQR_controller');

const router = express.Router();

router.post('/start-ride', processQRScanAndStartRide);

module.exports = router;