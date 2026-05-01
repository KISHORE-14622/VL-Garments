import express from 'express';
import { body, validationResult } from 'express-validator';
import InventoryItem from '../models/InventoryItem.js';
import { authRequired } from '../middleware/auth.js';

const router = express.Router();

// Get all inventory items (admin)
router.get('/', async (req, res) => {
  try {
    const items = await InventoryItem.find().sort({ date: -1 });
    return res.json(items);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch inventory', error: error.message });
  }
});

// Get my inventory items
router.get('/me', authRequired, async (req, res) => {
  const items = await InventoryItem.find({ staff: req.user.sub }).sort({ date: -1 });
  const total = items.reduce((sum, i) => sum + i.unitCost * i.quantity, 0);
  res.json({ items, total });
});

// Create inventory item
router.post(
  '/',
  authRequired,
  [body('name').notEmpty(), body('quantity').isInt({ min: 1 }), body('unitCost').isNumeric()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const { name, quantity, unitCost, cgstPercent, sgstPercent, supplier, date } = req.body;
    const doc = await InventoryItem.create({
      name,
      quantity,
      unitCost,
      cgstPercent: cgstPercent || 0,
      sgstPercent: sgstPercent || 0,
      supplier: supplier || '',
      staff: req.user.sub,
      date: date ? new Date(date) : new Date(),
    });
    res.status(201).json(doc);
  }
);

// Update inventory item
router.put('/:id', async (req, res) => {
  try {
    const { name, quantity, unitCost, cgstPercent, sgstPercent, supplier } = req.body;
    const update = {};
    if (name !== undefined) update.name = name;
    if (quantity !== undefined) update.quantity = quantity;
    if (unitCost !== undefined) update.unitCost = unitCost;
    if (cgstPercent !== undefined) update.cgstPercent = cgstPercent;
    if (sgstPercent !== undefined) update.sgstPercent = sgstPercent;
    if (supplier !== undefined) update.supplier = supplier;

    const item = await InventoryItem.findByIdAndUpdate(req.params.id, update, { new: true, runValidators: true });
    if (!item) return res.status(404).json({ message: 'Item not found' });
    return res.json(item);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update item', error: error.message });
  }
});

// Delete inventory item
router.delete('/:id', async (req, res) => {
  try {
    const item = await InventoryItem.findByIdAndDelete(req.params.id);
    if (!item) return res.status(404).json({ message: 'Item not found' });
    return res.json({ message: 'Item deleted' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete item', error: error.message });
  }
});

export default router;
