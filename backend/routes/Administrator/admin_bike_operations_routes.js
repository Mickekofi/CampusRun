const express = require('express');
const {
  getOverview,
  listBikes,
  updateBikeStatus,
  lockBike,
  updateUserAccountStatus,
} = require('../../controllers/Administrator/admin_bike_operations_controller');

const router = express.Router();

router.get('/overview', getOverview);
router.get('/bikes', listBikes);
router.patch('/bikes/:bikeId/status', updateBikeStatus);
router.patch('/bikes/:bikeId/lock', lockBike);
router.patch('/users/:userId/account-status', updateUserAccountStatus);

module.exports = router;
