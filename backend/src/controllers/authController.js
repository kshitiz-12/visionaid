const z = require('zod');
const { registerUserService, loginUserService } = require('../services/authService');

const registerSchema = z.object({
  email: z.email(),
  password: z.string().min(8),
  displayName: z.string().min(2),
});

const loginSchema = z.object({
  email: z.email(),
  password: z.string().min(8),
});

async function registerUser(req, res, next) {
  try {
    const payload = registerSchema.parse(req.body);
    const result = await registerUserService(payload);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: result,
      error: null,
    });
  } catch (error) {
    next(error);
  }
}

async function loginUser(req, res, next) {
  try {
    const payload = loginSchema.parse(req.body);
    const result = await loginUserService(payload);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: result,
      error: null,
    });
  } catch (error) {
    next(error);
  }
}

module.exports = {
  registerUser,
  loginUser,
};
