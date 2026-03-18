const express = require('express');

const {
  listPickupStations,
  listBookableBikes,
  selectBikeForUser,
} = require('../../controllers/Users/user_bikeSelection_controller');

const router = express.Router();

router.get('/pickup-stations', listPickupStations);
router.get('/bikes', listBookableBikes);
router.post('/select', selectBikeForUser);

module.exports = router;
