import express from 'express';
import { body, validationResult } from 'express-validator';
import Brand from '../models/Brand.js';

const router = express.Router();

// Get all brands
router.get('/', async (req, res) => {
  try {
    const brands = await Brand.find().sort({ name: 1 });
    return res.json(brands);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch brands', error: error.message });
  }
});

// Create a new brand
router.post(
  '/',
  [
    body('name').isString().notEmpty(),
    body('sellingRate').isNumeric(),
    body('costPerUnit').isNumeric(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { name, sellingRate, costPerUnit } = req.body;
      const brand = await Brand.create({
        name,
        sellingRate,
        costPerUnit,
      });
      return res.status(201).json(brand);
    } catch (error) {
      if (error.code === 11000) {
        return res.status(400).json({ message: 'Brand name already exists' });
      }
      return res.status(500).json({ message: 'Failed to create brand', error: error.message });
    }
  }
);

// Update a brand
router.put(
  '/:id',
  [
    body('name').optional().isString().notEmpty(),
    body('sellingRate').optional().isNumeric(),
    body('costPerUnit').optional().isNumeric(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { name, sellingRate, costPerUnit } = req.body;
      const brand = await Brand.findByIdAndUpdate(
        req.params.id,
        { name, sellingRate, costPerUnit },
        { new: true, runValidators: true }
      );
      if (!brand) return res.status(404).json({ message: 'Brand not found' });
      return res.json(brand);
    } catch (error) {
      if (error.code === 11000) {
        return res.status(400).json({ message: 'Brand name already exists' });
      }
      return res.status(500).json({ message: 'Failed to update brand', error: error.message });
    }
  }
);

// Delete a brand
router.delete('/:id', async (req, res) => {
  try {
    const brand = await Brand.findByIdAndDelete(req.params.id);
    if (!brand) return res.status(404).json({ message: 'Brand not found' });
    return res.json({ message: 'Brand deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete brand', error: error.message });
  }
});

export default router;
