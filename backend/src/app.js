const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const routes = require('./routes');
const { errorHandler, notFoundHandler } = require('./middlewares/errorHandler');
const { requestLogger } = require('./middlewares/requestLogger');
const { rateLimiter } = require('./middlewares/rateLimiter');
const { corsOrigins, isProduction } = require('./config/env');

const app = express();

app.set('trust proxy', 1);
app.use(helmet());
app.use(
  cors({
    origin(origin, callback) {
      // Native mobile clients often send no Origin header.
      if (!origin) {
        return callback(null, true);
      }

      if (!isProduction || corsOrigins.length === 0) {
        return callback(null, true);
      }

      if (corsOrigins.includes(origin) || corsOrigins.includes('*')) {
        return callback(null, true);
      }

      return callback(null, false);
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(requestLogger);
app.use(rateLimiter);

app.get('/', (_req, res) => {
  res.json({
    success: true,
    message: 'VisionAid++ API',
    data: {
      health: '/api/health',
      ready: '/api/ready',
      assistant: '/api/assistant/status',
    },
    error: null,
  });
});

app.get('/health', (_req, res) => {
  res.redirect(302, '/api/health');
});

app.use('/api', routes);
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
