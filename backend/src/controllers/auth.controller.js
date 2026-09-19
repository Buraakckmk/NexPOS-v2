const authService = require("../services/auth.service");

function isValidPin(pin) {
  return /^\d{6}$/.test(pin);
}

async function loginWithPin(req, res, next) {
  try {
    const { pin_code: pin } = req.body;

    if (!isValidPin(pin)) {
      return res.status(400).json({ message: "PIN 6 haneli sayi olmalidir." });
    }

    const user = await authService.findUserByPin(pin);

    if (!user || !user.is_active) {
      return res.status(401).json({ message: "Gecersiz PIN veya pasif kullanici." });
    }

    const accessToken = authService.signAccessToken(user);

    return res.status(200).json({
      token_type: "Bearer",
      access_token: accessToken,
      user: {
        id: user.id,
        full_name: user.full_name,
        role_id: user.role_id,
      },
    });
  } catch (error) {
    return next(error);
  }
}

function me(req, res) {
  return res.status(200).json({
    user_id: req.user.user_id,
    full_name: req.user.full_name,
    role_id: req.user.role_id,
  });
}

async function verifyAdmin(req, res, next) {
  try {
    const { pin_code: pin } = req.body;

    if (!isValidPin(pin)) {
      return res.status(400).json({ message: "PIN 6 haneli sayi olmalidir." });
    }

    const user = await authService.findUserByPin(pin);
    const isAdmin = Boolean(user && user.is_active && user.role_id === 1);

    return res.status(200).json({
      is_admin: isAdmin,
      full_name: isAdmin ? user.full_name : null,
    });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  loginWithPin,
  me,
  verifyAdmin,
};
