const {
  findProfileByUserId,
  upsertProfileByUserId,
} = require('../repositories/profileRepository');

async function getProfileService(userId, { email, fullName } = {}) {
  const existing = await findProfileByUserId(userId);

  if (existing) {
    return existing;
  }

  // First authenticated access creates the profile row.
  return upsertProfileByUserId(userId, {
    email: email || undefined,
    full_name: fullName || undefined,
  });
}

async function updateProfileService(userId, updates) {
  return upsertProfileByUserId(userId, updates);
}

module.exports = {
  getProfileService,
  updateProfileService,
};
