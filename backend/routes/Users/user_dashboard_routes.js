// the user dashboard routes js
const express = require('express');

const {
  getUserDashboardOverview,
} = require('../../controllers/Users/user_dashboard_controller');

const router = express.Router();

router.get('/overview', getUserDashboardOverview);

module.exports = router;
