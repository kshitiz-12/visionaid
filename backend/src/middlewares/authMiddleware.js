const { getSupabaseAdmin } = require('../config/supabase');

async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'Authentication required',
      data: null,
      error: { code: 'UNAUTHORIZED' },
    });
  }

  const token = authHeader.replace('Bearer ', '');
  const supabase = getSupabaseAdmin();

  if (!supabase) {
    return res.status(503).json({
      success: false,
      message: 'Authentication service unavailable',
      data: null,
      error: { code: 'SERVICE_UNAVAILABLE' },
    });
  }

  try {
    const { data, error } = await supabase.auth.getUser(token);

    if (error || !data.user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token',
        data: null,
        error: { code: 'INVALID_TOKEN' },
      });
    }

    req.user = {
      id: data.user.id,
      email: data.user.email,
    };

    return next();
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  requireAuth,
};
