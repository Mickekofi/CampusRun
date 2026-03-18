const express = require('express');
const {
  getPaymentDetails,
  authorizeMoMoPayment
} = require('../../controllers/Users/user_payment_controller');

const router = express.Router();

// Fetch the journey and price details
router.get('/details', getPaymentDetails);

// Authorize the payment (Creates a 'pending' transaction)
router.post('/authorize', authorizeMoMoPayment);

module.exports = router;