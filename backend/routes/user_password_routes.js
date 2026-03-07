const express = require('express');
const { setUserPassword } = require('../controllers/user_password');

const router = express.Router();

router.post('/set-password', setUserPassword);

module.exports = router;
