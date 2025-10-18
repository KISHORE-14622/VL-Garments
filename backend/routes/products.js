import express from 'express';
import { body, validationResult } from 'express-validator';
import Product from '../models/Product.js';
import { authRequired, adminOnly } from '../middleware/auth.js';

const router = express.Router();

router.get('/', async (_req, res) => {
  const items = await Product.find({ active: true }).sort({ createdAt: -1 });
  res.json(items);
});

router.post(
  '/',
  authRequired,
  adminOnly,
  [body('name').notEmpty(), body('price').isNumeric(), body('category').notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const item = await Product.create(req.body);
    res.status(201).json(item);
  }
);

router.put('/:id', authRequired, adminOnly, async (req, res) => {
  const updated = await Product.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(updated);
});

router.delete('/:id', authRequired, adminOnly, async (req, res) => {
  await Product.findByIdAndDelete(req.params.id);
  res.json({ ok: true });
});

export default router;


