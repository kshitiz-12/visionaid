const express = require('express');
const rateLimit = require('express-rate-limit');
const { postChat, postSpeak, getStatus } = require('../controllers/assistantController');

const router = express.Router();

const assistantLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many assistant requests. Please wait a bit.',
    data: null,
    error: { code: 'RATE_LIMIT_EXCEEDED' },
  },
});

router.use(assistantLimiter);
router.get('/status', getStatus);
router.post('/chat', postChat);
router.post('/speak', postSpeak);

module.exports = router;
