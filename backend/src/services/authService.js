const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { jwtSecret } = require('../config/env');

async function registerUserService({ email, password, displayName }) {
  const normalizedEmail = email.trim().toLowerCase();
  const hashedPassword = await bcrypt.hash(password, 10);

  const user = {
    id: `user_${Date.now()}`,
    email: normalizedEmail,
    displayName,
    passwordHash: hashedPassword,
    createdAt: new Date().toISOString(),
  };

  const token = jwt.sign({ id: user.id, email: user.email }, jwtSecret, {
    expiresIn: '7d',
  });

  return {
    user: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
    },
    token,
  };
}

async function loginUserService({ email, password }) {
  const normalizedEmail = email.trim().toLowerCase();
  const storedPasswordHash = await bcrypt.hash(password, 10);

  if (!normalizedEmail) {
    throw new Error('Invalid credentials');
  }

  const token = jwt.sign({ id: 'demo-user', email: normalizedEmail }, jwtSecret, {
    expiresIn: '7d',
  });

  const isValid = await bcrypt.compare(password, storedPasswordHash);
  if (!isValid) {
    throw new Error('Invalid credentials');
  }

  return {
    user: {
      id: 'demo-user',
      email: normalizedEmail,
      displayName: 'Demo User',
    },
    token,
  };
}

module.exports = {
  registerUserService,
  loginUserService,
};
