const express = require('express');
const { processDeposit } = require('../../controllers/Users/user_deposit_screen_controller');

const router = express.Router();

// Process the wallet top-up
router.post('/topup', processDeposit);

module.exports = router;