const customerService = require("../services/customer.service");

async function listCustomers(req, res, next) {
  try {
    const customers = await customerService.listCustomers(req.query);
    return res.status(200).json(customers);
  } catch (error) {
    return next(error);
  }
}

async function getCustomerById(req, res, next) {
  try {
    const customer = await customerService.getCustomerById(req.params.id);
    if (!customer) {
      return res.status(404).json({ message: "Musteri bulunamadi." });
    }
    return res.status(200).json(customer);
  } catch (error) {
    return next(error);
  }
}

async function createCustomer(req, res, next) {
  try {
    const { full_name, phone, email, note } = req.body;
    if (!full_name || !String(full_name).trim()) {
      return res.status(400).json({ message: "Musteri adi zorunludur." });
    }
    const customer = await customerService.createCustomer({ full_name, phone, email, note });
    return res.status(201).json(customer);
  } catch (error) {
    return next(error);
  }
}

async function updateCustomer(req, res, next) {
  try {
    const customer = await customerService.updateCustomer(req.params.id, req.body);
    if (!customer) {
      return res.status(404).json({ message: "Musteri bulunamadi." });
    }
    return res.status(200).json(customer);
  } catch (error) {
    return next(error);
  }
}

async function deleteCustomer(req, res, next) {
  try {
    const deleted = await customerService.deleteCustomer(req.params.id);
    if (!deleted) {
      return res.status(404).json({ message: "Musteri bulunamadi." });
    }
    return res.status(200).json({ message: "Musteri silindi." });
  } catch (error) {
    return next(error);
  }
}

async function addTransaction(req, res, next) {
  try {
    const { customer_id, order_id, type, amount, note } = req.body;
    if (!customer_id || !type || !amount) {
      return res.status(400).json({ message: "Musteri, islem tipi ve tutar zorunludur." });
    }
    const tx = await customerService.addTransaction({
      customer_id,
      order_id,
      type,
      amount,
      note,
      created_by_user_id: req.user.user_id,
    });
    return res.status(201).json(tx);
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  listCustomers,
  getCustomerById,
  createCustomer,
  updateCustomer,
  deleteCustomer,
  addTransaction,
};
