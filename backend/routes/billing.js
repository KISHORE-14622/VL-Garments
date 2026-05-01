import express from 'express';
import Brand from '../models/Brand.js';
import GstSetting from '../models/GstSetting.js';
import CompletedProduct from '../models/CompletedProduct.js';

const router = express.Router();

// Generate bill data — each completed product entry is a SEPARATE bill
router.get('/generate', async (req, res) => {
  try {
    let gst = await GstSetting.findOne();
    if (!gst) {
      gst = await GstSetting.create({ cgstPercent: 2.5, sgstPercent: 2.5 });
    }

    const { brandId, startDate, endDate } = req.query;

    // Build filter
    const filter = {};
    if (brandId) {
      const brand = await Brand.findById(brandId);
      if (!brand) return res.status(404).json({ message: 'Brand not found' });
      filter.brandName = brand.name;
    }
    if (startDate || endDate) {
      filter.date = {};
      if (startDate) filter.date.$gte = new Date(startDate);
      if (endDate) filter.date.$lte = new Date(endDate);
    }

    const entries = await CompletedProduct.find(filter).sort({ date: -1 });

    // Each entry = separate bill with its own GST
    const bills = entries.map((entry) => {
      const taxableAmount = entry.quantity * entry.sellingRate;
      const cgstAmount = (taxableAmount * gst.cgstPercent) / 100;
      const sgstAmount = (taxableAmount * gst.sgstPercent) / 100;

      return {
        entryId: entry._id,
        invoiceNumber: entry.invoiceNumber || '',
        brandName: entry.brandName || 'Unbranded',
        date: entry.date,
        totalQuantity: entry.quantity,
        sellingRate: entry.sellingRate,
        totalProductionCost: entry.quantity * entry.costPerUnit,
        taxableAmount,
        cgstPercent: gst.cgstPercent,
        cgstAmount,
        sgstPercent: gst.sgstPercent,
        sgstAmount,
        totalGst: cgstAmount + sgstAmount,
        grandTotal: taxableAmount + cgstAmount + sgstAmount,
      };
    });

    return res.json({
      gstSettings: {
        cgstPercent: gst.cgstPercent,
        sgstPercent: gst.sgstPercent,
        companyName: gst.companyName,
        companyAddress: gst.companyAddress,
        companyPhone: gst.companyPhone,
        gstin: gst.gstin,
        lastInvoiceNumber: gst.lastInvoiceNumber,
        invoicePrefix: gst.invoicePrefix,
      },
      brandBills: bills,
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to generate billing data', error: error.message });
  }
});

export default router;
