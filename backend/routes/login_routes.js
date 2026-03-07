const express = require('express');
const { loginWithRoleAccess } = require('../controllers/login_role_access');

const router = express.Router();

router.post('/login', loginWithRoleAccess);

module.exports = router;
