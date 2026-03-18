const express = require('express');
const { signup } = require('../../controllers/Users/signupController');

const router = express.Router();

router.post('/signup', signup);

module.exports = router;
