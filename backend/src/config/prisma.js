const { PrismaClient } = require('@prisma/client');
const { nodeEnv } = require('./env');

/** @type {PrismaClient | null} */
let prisma = null;

function getPrisma() {
  if (!process.env.DATABASE_URL) {
    return null;
  }

  if (!prisma) {
    prisma = new PrismaClient({
      log: nodeEnv === 'development' ? ['error', 'warn'] : ['error'],
    });
  }

  return prisma;
}

async function disconnectPrisma() {
  if (prisma) {
    await prisma.$disconnect();
    prisma = null;
  }
}

module.exports = {
  getPrisma,
  disconnectPrisma,
};
