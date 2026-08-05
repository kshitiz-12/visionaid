const express = require('express');
const authRoutes = require('./authRoutes');
const profileRoutes = require('./profileRoutes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/profile', profileRoutes);

module.exports = router;
