const { getProfileService, updateProfileService } = require('../services/profileService');

async function getProfile(req, res, next) {
  try {
    const profile = await getProfileService(req.user.id);

    res.status(200).json({
      success: true,
      message: 'Profile retrieved',
      data: profile,
      error: null,
    });
  } catch (error) {
    next(error);
  }
}

async function updateProfile(req, res, next) {
  try {
    const profile = await updateProfileService(req.user.id, req.body);

    res.status(200).json({
      success: true,
      message: 'Profile updated',
      data: profile,
      error: null,
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  getProfile,
  updateProfile,
};
