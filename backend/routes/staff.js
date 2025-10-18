import express from 'express';
import { body, validationResult } from 'express-validator';
import Staff from '../models/Staff.js';
import User from '../models/User.js';

const router = express.Router();

// Get all staff members
router.get('/', async (req, res) => {
  try {
    const staff = await Staff.find().sort({ createdAt: -1 });
    return res.json(staff);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch staff', error: error.message });
  }
});

// Get staff by ID
router.get('/:id', async (req, res) => {
  try {
    const staff = await Staff.findById(req.params.id);
    if (!staff) return res.status(404).json({ message: 'Staff not found' });
    return res.json(staff);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch staff', error: error.message });
  }
});

// Create a new staff member
router.post(
  '/',
  [
    body('userId').isString().notEmpty(),
    body('name').isString().notEmpty(),
    body('phoneNumber').isString().notEmpty(),
    body('email').isEmail(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { userId, name, phoneNumber, email } = req.body;
      
      // Check if user exists
      const user = await User.findById(userId);
      if (!user) return res.status(404).json({ message: 'User not found' });

      // Check if staff already exists for this user
      const existingStaff = await Staff.findOne({ userId });
      if (existingStaff) return res.status(400).json({ message: 'Staff record already exists for this user' });

      const staff = await Staff.create({
        userId,
        name,
        phoneNumber,
        email,
        joinedDate: new Date(),
        isActive: true,
      });

      return res.status(201).json(staff);
    } catch (error) {
      return res.status(500).json({ message: 'Failed to create staff', error: error.message });
    }
  }
);

// Update staff member
router.put('/:id', async (req, res) => {
  try {
    const { name, phoneNumber, isActive } = req.body;
    const staff = await Staff.findByIdAndUpdate(
      req.params.id,
      { name, phoneNumber, isActive },
      { new: true, runValidators: true }
    );
    
    if (!staff) return res.status(404).json({ message: 'Staff not found' });
    return res.json(staff);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update staff', error: error.message });
  }
});

// Delete staff member
router.delete('/:id', async (req, res) => {
  try {
    const staff = await Staff.findByIdAndDelete(req.params.id);
    if (!staff) return res.status(404).json({ message: 'Staff not found' });
    return res.json({ message: 'Staff deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete staff', error: error.message });
  }
});

// Utility endpoint to create staff records for existing users (migration)
router.post('/migrate-users', async (req, res) => {
  try {
    const users = await User.find({ role: 'staff' });
    const created = [];
    const skipped = [];
    
    for (const user of users) {
      // Check if staff record already exists
      const existingStaff = await Staff.findOne({ userId: user._id });
      if (existingStaff) {
        skipped.push(user.email);
        continue;
      }
      
      // Create staff record
      const staff = await Staff.create({
        userId: user._id,
        name: user.name,
        phoneNumber: user.email, // Use email as placeholder if phone not available
        email: user.email,
        joinedDate: user.createdAt || new Date(),
        isActive: true,
      });
      
      created.push(staff.email);
    }
    
    return res.json({ 
      message: 'Migration complete',
      created: created.length,
      skipped: skipped.length,
      createdStaff: created,
      skippedStaff: skipped
    });
  } catch (error) {
    return res.status(500).json({ message: 'Migration failed', error: error.message });
  }
});

export default router;
