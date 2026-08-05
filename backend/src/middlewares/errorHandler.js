function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.originalUrl}`,
    data: null,
    error: { code: 'NOT_FOUND' },
  });
}

function errorHandler(error, _req, res, _next) {
  const statusCode = error.statusCode || 500;

  res.status(statusCode).json({
    success: false,
    message: error.message || 'Internal server error',
    data: null,
    error: {
      code: error.code || 'INTERNAL_SERVER_ERROR',
      details: error.details || undefined,
    },
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
