import express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';
import User from '../models/User.js';
import { authRequired } from '../middleware/auth.js';

const router = express.Router();

router.post(
  '/register',
  [
    body('name').isString().notEmpty(),
    body('email').isEmail(),
    body('password').isLength({ min: 6 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const { name, email, password } = req.body;
    const existing = await User.findOne({ email });
    if (existing) return res.status(400).json({ message: 'Email already in use' });
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({ name, email, passwordHash, role: 'admin' });
    return res.status(201).json({ id: user._id.toString(), name: user.name, email: user.email, role: user.role });
  }
);

router.post(
  '/login',
  [body('email').isEmail(), body('password').isString().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    const { email, password } = req.body;
    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ message: 'Invalid credentials' });
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(401).json({ message: 'Invalid credentials' });
    const token = jwt.sign({ sub: user.id, role: user.role, name: user.name }, process.env.JWT_SECRET, { expiresIn: '365d' });
    return res.json({ 
      token, 
      user: { 
        id: user.id, 
        name: user.name, 
        email: user.email, 
        role: user.role,
        hasPin: !!user.pinHash,
        biometricEnabled: user.biometricEnabled 
      } 
    });
  }
);

// Set or update PIN
router.post(
  '/set-pin',
  authRequired,
  [body('pin').isString().isLength({ min: 4, max: 6 }).matches(/^\d+$/)],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    
    try {
      const { pin } = req.body;
      const pinHash = await bcrypt.hash(pin, 10);
      
      await User.findByIdAndUpdate(req.user.sub, { pinHash });
      
      return res.json({ success: true, message: 'PIN set successfully' });
    } catch (error) {
      return res.status(500).json({ message: 'Failed to set PIN', error: error.message });
    }
  }
);

// Verify PIN
router.post(
  '/verify-pin',
  authRequired,
  [body('pin').isString().notEmpty()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    
    try {
      const { pin } = req.body;
      const user = await User.findById(req.user.sub);
      
      if (!user || !user.pinHash) {
        return res.status(400).json({ message: 'PIN not set' });
      }
      
      const isValid = await bcrypt.compare(pin, user.pinHash);
      
      if (!isValid) {
        return res.status(401).json({ message: 'Invalid PIN' });
      }
      
      return res.json({ success: true, message: 'PIN verified' });
    } catch (error) {
      return res.status(500).json({ message: 'Failed to verify PIN', error: error.message });
    }
  }
);

// Toggle biometric
router.post(
  '/toggle-biometric',
  authRequired,
  [body('enabled').isBoolean()],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    
    try {
      const { enabled } = req.body;
      
      await User.findByIdAndUpdate(req.user.sub, { biometricEnabled: enabled });
      
      return res.json({ success: true, biometricEnabled: enabled });
    } catch (error) {
      return res.status(500).json({ message: 'Failed to toggle biometric', error: error.message });
    }
  }
);

// Get current user info (for checking PIN/biometric status)
router.get('/me', authRequired, async (req, res) => {
  try {
    const user = await User.findById(req.user.sub);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    return res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      hasPin: !!user.pinHash,
      biometricEnabled: user.biometricEnabled
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to get user', error: error.message });
  }
});

// Remove PIN
router.delete('/pin', authRequired, async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.user.sub, { pinHash: null, biometricEnabled: false });
    return res.json({ success: true, message: 'PIN removed' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to remove PIN', error: error.message });
  }
});

// Update profile
router.put(
  '/update-profile',
  authRequired,
  [
    body('name').isString().notEmpty(),
    body('email').isEmail(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    
    try {
      const { name, email } = req.body;
      const existing = await User.findOne({ email, _id: { $ne: req.user.sub } });
      if (existing) return res.status(400).json({ message: 'Email already in use' });
      
      const user = await User.findByIdAndUpdate(
        req.user.sub,
        { name, email },
        { new: true }
      );
      
      return res.json({
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        hasPin: !!user.pinHash,
        biometricEnabled: user.biometricEnabled
      });
    } catch (error) {
      return res.status(500).json({ message: 'Failed to update profile', error: error.message });
    }
  }
);

// Change password
router.put(
  '/change-password',
  authRequired,
  [
    body('currentPassword').isString().notEmpty(),
    body('newPassword').isLength({ min: 6 }),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });
    
    try {
      const { currentPassword, newPassword } = req.body;
      const user = await User.findById(req.user.sub);
      
      const isValid = await bcrypt.compare(currentPassword, user.passwordHash);
      if (!isValid) return res.status(400).json({ message: 'Invalid current password' });
      
      const passwordHash = await bcrypt.hash(newPassword, 10);
      await User.findByIdAndUpdate(req.user.sub, { passwordHash });
      
      return res.json({ success: true, message: 'Password changed successfully' });
    } catch (error) {
      return res.status(500).json({ message: 'Failed to change password', error: error.message });
    }
  }
);

export default router;
