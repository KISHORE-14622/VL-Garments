import express from 'express';
import { body, validationResult } from 'express-validator';
import Rate from '../models/Rate.js';
import { authRequired, adminOnly } from '../middleware/auth.js';

const router = express.Router();

router.get('/', async (_req, res) => {
  const items = await Rate.find({}).sort({ category: 1 });
  res.json(items);
});

router.post('/', authRequired, adminOnly, [body('category').notEmpty(), body('amount').isNumeric()], async (req, res) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
  const existing = await Rate.findOne({ category: req.body.category });
  if (existing) {
    existing.amount = req.body.amount;
    await existing.save();
    return res.json(existing);
  }
  const created = await Rate.create(req.body);
  res.status(201).json(created);
});

export default router;


