import express from 'express';
import { body, validationResult } from 'express-validator';
import CompletedProduct from '../models/CompletedProduct.js';
import GstSetting from '../models/GstSetting.js';

const router = express.Router();

// Get all completed production entries
router.get('/', async (req, res) => {
  try {
    const entries = await CompletedProduct.find().sort({ date: -1, createdAt: -1 });
    return res.json(entries);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch completed production', error: error.message });
  }
});

// Create a new entry — auto-assigns next invoice number
router.post(
  '/',
  [
    body('date').isISO8601(),
    body('quantity').isNumeric(),
    body('sellingRate').isNumeric(),
    body('costPerUnit').isNumeric(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) return res.status(400).json({ errors: errors.array() });

    try {
      const { date, quantity, sellingRate, costPerUnit, notes, brandName } = req.body;

      // Get and increment invoice counter
      let gst = await GstSetting.findOne();
      if (!gst) {
        gst = await GstSetting.create({ cgstPercent: 2.5, sgstPercent: 2.5, lastInvoiceNumber: 0, invoicePrefix: 'VLG-' });
      }
      const nextNum = (gst.lastInvoiceNumber || 0) + 1;
      const invoiceNumber = `${gst.invoicePrefix || 'VLG-'}${String(nextNum).padStart(4, '0')}`;

      // Update the counter
      gst.lastInvoiceNumber = nextNum;
      await gst.save();

      const entry = await CompletedProduct.create({
        date: new Date(date),
        quantity,
        sellingRate,
        costPerUnit,
        brandName: brandName || '',
        notes: notes || '',
        invoiceNumber,
      });
      return res.status(201).json(entry);
    } catch (error) {
      return res.status(500).json({ message: 'Failed to create completed production entry', error: error.message });
    }
  }
);

// Delete an entry
router.delete('/:id', async (req, res) => {
  try {
    const entry = await CompletedProduct.findByIdAndDelete(req.params.id);
    if (!entry) return res.status(404).json({ message: 'Entry not found' });
    return res.json({ message: 'Entry deleted successfully' });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to delete entry', error: error.message });
  }
});

export default router;
