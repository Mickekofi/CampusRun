const express = require('express');
const { phone } = require('../controllers/phone');

const router = express.Router();

router.post('/phone', phone);

module.exports = router;
