const express = require('express');
const {
  getPendingSelection,
  getDropoffStations,
  getFareEstimate,
  confirmSelection,
  cancelSelection
} = require('../../controllers/Users/user_confirm_bike_controller');

const router = express.Router();

router.get('/pending', getPendingSelection);
router.get('/dropoff-stations', getDropoffStations);
router.post('/estimate', getFareEstimate);
router.post('/confirm', confirmSelection);
router.post('/cancel', cancelSelection);

module.exports = router;