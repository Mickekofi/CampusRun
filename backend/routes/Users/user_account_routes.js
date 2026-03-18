const express = require('express');
const { getUserProfile } = require('../../controllers/Users/user_account_controller');

const router = express.Router();

router.get('/profile', getUserProfile);

module.exports = router;