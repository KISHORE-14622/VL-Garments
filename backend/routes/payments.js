import express from 'express';
import { body, validationResult } from 'express-validator';
import Payment from '../models/Payment.js';
import { authRequired, adminOnly } from '../middleware/auth.js';

const router = express.Router();

router.get('/', authRequired, adminOnly, async (_req, res) => {
  const items = await Payment.find({}).sort({ createdAt: -1 }).populate('staff', 'name email');
  res.json(items);
});

router.post(
  '/',
  authRequired,
  adminOnly,
  [
    body('staff').isString().notEmpty(),
    body('periodStart').isISO8601(),
    body('periodEnd').isISO8601(),
    body('amount').isNumeric(),
    body('status').isIn(['pending', 'paid']),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const doc = await Payment.create(req.body);
    res.status(201).json(doc);
  }
);

router.put('/:id', authRequired, adminOnly, async (req, res) => {
  const updated = await Payment.findByIdAndUpdate(req.params.id, req.body, { new: true });
  res.json(updated);
});

export default router;


