const {
  findProfileByUserId,
  upsertProfileByUserId,
} = require('../repositories/profileRepository');
const { createAppError } = require('../utils/appError');

async function getProfileService(userId) {
  const profile = await findProfileByUserId(userId);

  if (!profile) {
    throw createAppError('Profile not found', {
      statusCode: 404,
      code: 'PROFILE_NOT_FOUND',
    });
  }

  return profile;
}

async function updateProfileService(userId, updates) {
  return upsertProfileByUserId(userId, updates);
}

module.exports = {
  getProfileService,
  updateProfileService,
};
