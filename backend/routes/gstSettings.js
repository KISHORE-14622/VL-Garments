import express from 'express';
import GstSetting from '../models/GstSetting.js';

const router = express.Router();

// Get current GST settings (creates default if none exist)
router.get('/', async (req, res) => {
  try {
    let settings = await GstSetting.findOne();
    if (!settings) {
      settings = await GstSetting.create({
        cgstPercent: 2.5,
        sgstPercent: 2.5,
        companyName: 'Vijayalakshmi Garments',
        companyAddress: '',
        companyPhone: '',
        gstin: '',
      });
    }
    return res.json(settings);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to fetch GST settings', error: error.message });
  }
});

// Update GST settings (upsert — single document)
router.put('/', async (req, res) => {
  try {
    const { cgstPercent, sgstPercent, companyName, companyAddress, companyPhone, gstin, lastInvoiceNumber, invoicePrefix } = req.body;
    const update = {};
    if (cgstPercent !== undefined) update.cgstPercent = cgstPercent;
    if (sgstPercent !== undefined) update.sgstPercent = sgstPercent;
    if (companyName !== undefined) update.companyName = companyName;
    if (companyAddress !== undefined) update.companyAddress = companyAddress;
    if (companyPhone !== undefined) update.companyPhone = companyPhone;
    if (gstin !== undefined) update.gstin = gstin;
    if (lastInvoiceNumber !== undefined) update.lastInvoiceNumber = lastInvoiceNumber;
    if (invoicePrefix !== undefined) update.invoicePrefix = invoicePrefix;

    let settings = await GstSetting.findOne();
    if (!settings) {
      settings = await GstSetting.create({
        cgstPercent: cgstPercent ?? 2.5,
        sgstPercent: sgstPercent ?? 2.5,
        companyName: companyName ?? 'Vijayalakshmi Garments',
        companyAddress: companyAddress ?? '',
        companyPhone: companyPhone ?? '',
        gstin: gstin ?? '',
      });
    } else {
      Object.assign(settings, update);
      await settings.save();
    }
    return res.json(settings);
  } catch (error) {
    return res.status(500).json({ message: 'Failed to update GST settings', error: error.message });
  }
});

export default router;
