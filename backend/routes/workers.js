import express from 'express';
import { body, validationResult } from 'express-validator';
import Worker from '../models/Worker.js';

const router = express.Router();

// Get all workers
router.get('/', async (req, res) => {
  try {
    const workers = await Worker.find().sort({ createdAt: -1 });
    return res.json(workers);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch workers', error: error.message });
  }
});

// Get worker by ID
router.get('/:id', async (req, res) => {
  try {
    const worker = await Worker.findById(req.params.id);
    if (!worker) return res.status(404).json({ message: 'Worker not found' });
    return res.json(worker);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch worker', error: error.message });
  }
});

// Create a new worker
router.post(
  '/',
  [
    body('name').isString().notEmpty(),
    body('phoneNumber').isString().notEmpty(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { name, phoneNumber, address, notes } = req.body;

      const worker = await Worker.create({
        name,
        phoneNumber,
        address,
        notes,
        joinedDate: new Date(),
        isActive: true,
      });

      return res.status(201).json(worker);
    } catch (error) {
      return res.status(500).json({ message: 'Failed to create worker', error: error.message });
    }
  }
);

// Update worker
router.put('/:id', async (req, res) => {
  try {
    const { name, phoneNumber, address, notes, isActive } = req.body;
    const worker = await Worker.findByIdAndUpdate(
      req.params.id,
      { name, phoneNumber, address, notes, isActive },
      { new: true, runValidators: true }
    );
    
    if (!worker) return res.status(404).json({ message: 'Worker not found' });
    return res.json(worker);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update worker', error: error.message });
  }
});

// Delete worker
router.delete('/:id', async (req, res) => {
  try {
    const worker = await Worker.findByIdAndDelete(req.params.id);
    if (!worker) return res.status(404).json({ message: 'Worker not found' });
    return res.json({ message: 'Worker deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete worker', error: error.message });
  }
});

export default router;
