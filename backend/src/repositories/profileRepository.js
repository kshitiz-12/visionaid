const { getPrisma } = require('../config/prisma');
const { createAppError } = require('../utils/appError');

function mapProfile(profile) {
  if (!profile) {
    return null;
  }

  return {
    id: profile.id,
    full_name: profile.fullName,
    email: profile.email,
    created_at: profile.createdAt,
    updated_at: profile.updatedAt,
  };
}

function requirePrisma() {
  const prisma = getPrisma();
  if (!prisma) {
    throw createAppError('Database unavailable', {
      statusCode: 503,
      code: 'DATABASE_UNAVAILABLE',
    });
  }
  return prisma;
}

async function findProfileByUserId(userId) {
  const prisma = requirePrisma();
  const profile = await prisma.profile.findUnique({
    where: { id: userId },
  });
  return mapProfile(profile);
}

async function upsertProfileByUserId(userId, updates = {}) {
  const prisma = requirePrisma();

  const data = {};
  if (typeof updates.full_name === 'string') {
    data.fullName = updates.full_name.trim();
  }
  if (typeof updates.email === 'string') {
    data.email = updates.email.trim().toLowerCase();
  }

  const profile = await prisma.profile.upsert({
    where: { id: userId },
    create: {
      id: userId,
      fullName: data.fullName ?? null,
      email: data.email ?? null,
    },
    update: data,
  });

  return mapProfile(profile);
}

module.exports = {
  findProfileByUserId,
  upsertProfileByUserId,
};
