import express from 'express';
import { body, validationResult } from 'express-validator';
import InventoryItem from '../models/InventoryItem.js';
import { authRequired } from '../middleware/auth.js';

const router = express.Router();

router.get('/me', authRequired, async (req, res) => {
  const items = await InventoryItem.find({ staff: req.user.sub }).sort({ date: -1 });
  const total = items.reduce((sum, i) => sum + i.unitCost * i.quantity, 0);
  res.json({ items, total });
});

router.post(
  '/',
  authRequired,
  [body('name').notEmpty(), body('quantity').isInt({ min: 1 }), body('unitCost').isNumeric()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const doc = await InventoryItem.create({ ...req.body, staff: req.user.sub });
    res.status(201).json(doc);
  }
);

export default router;


