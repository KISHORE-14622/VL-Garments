import express from 'express';
import Supplier from '../models/Supplier.js';
import { adminOnly, authRequired } from '../middleware/auth.js';

const router = express.Router();

router.get('/', authRequired, async (req, res) => {
  try {
    const items = await Supplier.find().sort({ name: 1 });
    res.json(items);
  } catch (error) {
    res.status(500).json({ message: 'Failed to fetch suppliers', error: error.message });
  }
});

router.post('/', authRequired, adminOnly, async (req, res) => {
  try {
    const doc = await Supplier.create({ name: req.body.name });
    res.status(201).json(doc);
  } catch (error) {
    res.status(400).json({ message: 'Failed to create supplier', error: error.message });
  }
});

router.put('/:id', authRequired, adminOnly, async (req, res) => {
  try {
    const doc = await Supplier.findByIdAndUpdate(req.params.id, { name: req.body.name }, { new: true });
    res.json(doc);
  } catch (error) {
    res.status(400).json({ message: 'Failed to update supplier', error: error.message });
  }
});

router.delete('/:id', authRequired, adminOnly, async (req, res) => {
  try {
    await Supplier.findByIdAndDelete(req.params.id);
    res.json({ message: 'Deleted' });
  } catch (error) {
    res.status(400).json({ message: 'Failed to delete supplier', error: error.message });
  }
});

export default router;
