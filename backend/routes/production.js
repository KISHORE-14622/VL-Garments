import express from 'express';
import { body, validationResult } from 'express-validator';
import Production from '../models/Production.js';
import Rate from '../models/Rate.js';
import { authRequired } from '../middleware/auth.js';

const router = express.Router();

router.get('/me', authRequired, async (req, res) => {
  const items = await Production.find({ staff: req.user.sub }).sort({ date: -1 });
  res.json(items);
});

router.post(
  '/',
  authRequired,
  [body('category').notEmpty(), body('quantity').isInt({ min: 1 }), body('date').isISO8601()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const doc = await Production.create({ ...req.body, staff: req.user.sub });
    res.status(201).json(doc);
  }
);

router.get('/weekly-total/:staffId', authRequired, async (req, res) => {
  const { staffId } = req.params;
  const since = new Date();
  since.setDate(since.getDate() - 7);
  const entries = await Production.find({ staff: staffId, date: { $gte: since } });
  const rates = await Rate.find({});
  const rateMap = Object.fromEntries(rates.map(r => [r.category, r.amount]));
  const total = entries.reduce((sum, e) => sum + (rateMap[e.category] || 0) * e.quantity, 0);
  res.json({ total, count: entries.length });
});

export default router;


