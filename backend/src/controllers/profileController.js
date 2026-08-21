const { z } = require('zod');
const { getProfileService, updateProfileService } = require('../services/profileService');

const updateProfileSchema = z
  .object({
    full_name: z.string().trim().min(1).max(120).optional(),
    email: z.string().trim().email().max(254).optional(),
  })
  .refine((data) => data.full_name !== undefined || data.email !== undefined, {
    message: 'At least one of full_name or email is required',
  });

async function getProfile(req, res, next) {
  try {
    const profile = await getProfileService(req.user.id, {
      email: req.user.email,
    });

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
    const payload = updateProfileSchema.parse(req.body);
    const profile = await updateProfileService(req.user.id, payload);

    res.status(200).json({
      success: true,
      message: 'Profile updated',
      data: profile,
      error: null,
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return next(
        Object.assign(new Error('Invalid profile payload'), {
          statusCode: 400,
          code: 'VALIDATION_ERROR',
          details: error.flatten(),
        }),
      );
    }
    return next(error);
  }
}

module.exports = {
  getProfile,
  updateProfile,
};
