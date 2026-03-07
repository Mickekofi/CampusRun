const express = require('express');
const { setUserPassword } = require('../controllers/user_password_controller');

const router = express.Router();

router.post('/set-password', setUserPassword);

module.exports = router;
