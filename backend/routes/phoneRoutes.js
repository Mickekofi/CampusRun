const express = require('express');
const { phone } = require('../controllers/phone_controller');

const router = express.Router();

router.post('/phone', phone);

module.exports = router;
