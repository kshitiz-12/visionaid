const http = require('http');

process.env.NODE_ENV = process.env.NODE_ENV || 'test';
process.env.PORT = process.env.PORT || '0';

const app = require('../src/app');
const { disconnectPrisma } = require('../src/config/prisma');

const server = app.listen(0, () => {
  const address = server.address();
  const port = typeof address === 'object' && address ? address.port : 3000;
  console.log(`VisionAid++ backend test server on port ${port}`);
  runHealthTest(port);
});

async function shutdown(exitCode = 0) {
  server.close(async () => {
    await disconnectPrisma();
    process.exit(exitCode);
  });
}

function request(port, path) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path,
        method: 'GET',
        timeout: 5000,
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => {
          resolve({ statusCode: res.statusCode, body: JSON.parse(body) });
        });
      },
    );

    req.on('error', reject);
    req.end();
  });
}

async function runHealthTest(port) {
  try {
    const health = await request(port, '/api/health');
    if (health.statusCode !== 200 || health.body.data?.status !== 'ok') {
      throw new Error('Health check failed');
    }

    const unauthorized = await request(port, '/api/profile');
    if (unauthorized.statusCode !== 401) {
      throw new Error(`Expected profile 401, got ${unauthorized.statusCode}`);
    }

    console.log('Backend production smoke tests passed');
    await shutdown(0);
  } catch (error) {
    console.error('Backend smoke tests failed:', error.message);
    await shutdown(1);
  }
}
