const jwt = require('jsonwebtoken');
const { jwtSecret } = require('../config/env');

function requireAuth(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required',
      data: null,
      error: { code: 'UNAUTHORIZED' },
    });
  }

  try {
    const payload = jwt.verify(token, jwtSecret);
    req.user = payload;
    return next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
      data: null,
      error: { code: 'INVALID_TOKEN' },
    });
  }
}

module.exports = {
  requireAuth,
};
