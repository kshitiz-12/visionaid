const express = require('express');
const { getProfile, updateProfile } = require('../controllers/profileController');
const { requireAuth } = require('../middlewares/authMiddleware');

const router = express.Router();

router.use(requireAuth);
router.get('/', getProfile);
router.patch('/', updateProfile);

module.exports = router;
