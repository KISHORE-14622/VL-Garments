import express from 'express';
import { body, validationResult } from 'express-validator';
import Rate from '../models/Rate.js';
import { authRequired, adminOnly } from '../middleware/auth.js';

const router = express.Router();

router.get('/', async (_req, res) => {
  const items = await Rate.find({}).sort({ category: 1 });
  res.json(items);
});

router.post('/', [body('category').notEmpty(), body('amount').isNumeric()], async (req, res) => {
  console.log('📝 Rate update request received:', req.body);
  
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    console.log('❌ Validation errors:', errors.array());
    return res.status(400).json({ errors: errors.array() });
  }
  
  try {
    const existing = await Rate.findOne({ category: req.body.category });
    if (existing) {
      console.log(`✏️  Updating existing rate for ${req.body.category}: ${existing.amount} → ${req.body.amount}`);
      existing.amount = req.body.amount;
      await existing.save();
      console.log('✅ Rate updated successfully');
      return res.json(existing);
    }
    
    console.log(`➕ Creating new rate for ${req.body.category}: ${req.body.amount}`);
    const created = await Rate.create(req.body);
    console.log('✅ Rate created successfully');
    res.status(201).json(created);
  } catch (error) {
    console.error('❌ Error saving rate:', error);
    res.status(500).json({ message: 'Failed to save rate', error: error.message });
  }
});

export default router;


