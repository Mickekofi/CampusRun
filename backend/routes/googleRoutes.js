const express = require('express');
const { google } = require('../controllers/google_controller');

const router = express.Router();

router.post('/google', google);

module.exports = router;
