const express = require('express');
const {
	getUserMonitorStats,
	listUsers,
	updateUserStatus,
} = require('../../controllers/Administrator/admin_user_monitor_controller');

const router = express.Router();

router.get('/stats', getUserMonitorStats);
router.get('/users', listUsers);
router.patch('/users/:userId/status', updateUserStatus);

module.exports = router;
