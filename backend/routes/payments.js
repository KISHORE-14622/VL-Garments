import express from 'express';
import { body, validationResult } from 'express-validator';
import Payment from '../models/Payment.js';
import { authRequired, adminOnly } from '../middleware/auth.js';
import Razorpay from 'razorpay';
import crypto from 'crypto';

const router = express.Router();

// Initialize Razorpay instance
let razorpay = null;
if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET) {
  razorpay = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID,
    key_secret: process.env.RAZORPAY_KEY_SECRET,
  });
}

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

// Create Razorpay order
router.post('/razorpay/create-order', authRequired, adminOnly, async (req, res) => {
  try {
    if (!razorpay) {
      return res.status(500).json({ error: 'Razorpay is not configured' });
    }

    const { amount, currency = 'INR', receipt } = req.body;

    if (!amount) {
      return res.status(400).json({ error: 'Amount is required' });
    }

    const options = {
      amount: Math.round(amount * 100), // Razorpay expects amount in paise
      currency,
      receipt: receipt || `receipt_${Date.now()}`,
    };

    const order = await razorpay.orders.create(options);
    res.json({
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      keyId: process.env.RAZORPAY_KEY_ID,
    });
  } catch (error) {
    console.error('Error creating Razorpay order:', error);
    res.status(500).json({ error: 'Failed to create Razorpay order' });
  }
});

// Verify Razorpay payment
router.post('/razorpay/verify', authRequired, adminOnly, async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Verify signature
    const body = razorpay_order_id + '|' + razorpay_payment_id;
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(body.toString())
      .digest('hex');

    const isValid = expectedSignature === razorpay_signature;

    if (isValid) {
      res.json({ verified: true });
    } else {
      res.status(400).json({ verified: false, error: 'Invalid signature' });
    }
  } catch (error) {
    console.error('Error verifying Razorpay payment:', error);
    res.status(500).json({ error: 'Failed to verify payment' });
  }
});

export default router;


