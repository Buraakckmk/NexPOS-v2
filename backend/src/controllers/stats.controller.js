const statsService = require("../services/stats.service");

async function getDailySummary(req, res, next) {
  try {
    const summary = await statsService.getDailySummary();
    return res.status(200).json(summary);
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  getDailySummary
};
