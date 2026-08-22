const { Prisma } = require('@prisma/client');
const { ZodError } = require('zod');
const { isProduction } = require('../config/env');
const { AppError } = require('../utils/appError');

function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.originalUrl}`,
    data: null,
    error: { code: 'NOT_FOUND' },
  });
}

function mapPrismaError(error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2025') {
      return new AppError('Resource not found', {
        statusCode: 404,
        code: 'NOT_FOUND',
      });
    }

    if (error.code === 'P2002') {
      return new AppError('Resource already exists', {
        statusCode: 409,
        code: 'CONFLICT',
      });
    }

    if (error.code === 'P2003') {
      return new AppError('Related resource not found', {
        statusCode: 400,
        code: 'FOREIGN_KEY_VIOLATION',
      });
    }
  }

  if (error instanceof Prisma.PrismaClientInitializationError) {
    return new AppError('Database unavailable', {
      statusCode: 503,
      code: 'DATABASE_UNAVAILABLE',
    });
  }

  return null;
}

function errorHandler(error, _req, res, _next) {
  let mapped = mapPrismaError(error) || error;

  if (error instanceof ZodError) {
    mapped = new AppError('Validation failed', {
      statusCode: 400,
      code: 'VALIDATION_ERROR',
      details: error.flatten(),
    });
  }

  const statusCode = mapped.statusCode || 500;
  const code = mapped.code || 'INTERNAL_SERVER_ERROR';

  if (statusCode >= 500) {
    console.error('[error]', mapped);
  }

  const hideDetails = statusCode >= 500 && isProduction &&
    code !== 'AI_NOT_CONFIGURED' &&
    code !== 'TTS_NOT_CONFIGURED' &&
    code !== 'AI_UPSTREAM';

  const message = hideDetails
      ? 'Internal server error'
      : mapped.message || 'Internal server error';

  res.status(statusCode).json({
    success: false,
    message,
    data: null,
    error: {
      code,
      details: isProduction && statusCode >= 500 ? undefined : mapped.details,
    },
  });
}

module.exports = {
  notFoundHandler,
  errorHandler,
};
