const express = require('express');
const { google } = require('../controllers/google');

const router = express.Router();

router.post('/google', google);

module.exports = router;
