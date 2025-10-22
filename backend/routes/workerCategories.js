import express from 'express';
import { body, validationResult } from 'express-validator';
import WorkerCategory from '../models/WorkerCategory.js';

const router = express.Router();

// List categories
router.get('/', async (req, res) => {
  try {
    const categories = await WorkerCategory.find().sort({ createdAt: -1 });
    return res.json(categories);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch categories', error: error.message });
  }
});

// Create category
router.post(
  '/',
  [body('name').isString().trim().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { name } = req.body;
      const existing = await WorkerCategory.findOne({ name: new RegExp(`^${name}$`, 'i') });
      if (existing) return res.status(400).json({ message: 'Category already exists' });

      const cat = await WorkerCategory.create({ name });
      return res.status(201).json(cat);
    } catch (error) {
      return res.status(500).json({ message: 'Failed to create category', error: error.message });
    }
  }
);

// Update category
router.put('/:id', async (req, res) => {
  try {
    const { name, isActive } = req.body;
    const cat = await WorkerCategory.findByIdAndUpdate(
      req.params.id,
      { name, isActive },
      { new: true, runValidators: true }
    );
    if (!cat) return res.status(404).json({ message: 'Category not found' });
    return res.json(cat);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update category', error: error.message });
  }
});

// Delete category
router.delete('/:id', async (req, res) => {
  try {
    const cat = await WorkerCategory.findByIdAndDelete(req.params.id);
    if (!cat) return res.status(404).json({ message: 'Category not found' });
    return res.json({ message: 'Category deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete category', error: error.message });
  }
});

export default router;
