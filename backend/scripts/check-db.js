require('dotenv').config({ quiet: true });
const { PrismaClient } = require('@prisma/client');

function withSsl(url) {
  if (!url) return url;
  if (/sslmode=/i.test(url)) return url;
  return url.includes('?') ? `${url}&sslmode=require` : `${url}?sslmode=require`;
}

async function main() {
  const original = process.env.DATABASE_URL || '';
  process.env.DATABASE_URL = withSsl(original);
  process.env.DIRECT_URL = withSsl(process.env.DIRECT_URL || '');

  const prisma = new PrismaClient();
  try {
    await prisma.$queryRaw`SELECT 1 as ok`;
    console.log('CONNECT_OK');
  } catch (error) {
    console.log('CONNECT_FAIL');
    console.log(String(error.message).split('\n')[0]);
  } finally {
    await prisma.$disconnect();
  }
}

main();
