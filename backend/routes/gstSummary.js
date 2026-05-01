import express from 'express';
import InventoryItem from '../models/InventoryItem.js';
import CompletedProduct from '../models/CompletedProduct.js';
import GstSetting from '../models/GstSetting.js';

const router = express.Router();

// GET /api/gst-summary — Calculate Net GST Payable
// Net GST = Output GST (on sales) − Input GST (on material purchases)
// Positive = pay to government, Negative = ITC (Input Tax Credit)
router.get('/', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    // Get GST settings for output GST calculation
    let gst = await GstSetting.findOne();
    if (!gst) {
      gst = await GstSetting.create({ cgstPercent: 2.5, sgstPercent: 2.5 });
    }

    // ─── Build date filter ───
    const dateFilter = {};
    if (startDate || endDate) {
      dateFilter.date = {};
      if (startDate) dateFilter.date.$gte = new Date(startDate);
      if (endDate) dateFilter.date.$lte = new Date(endDate);
    }

    // ─── INPUT GST: from inventory purchases ───
    const inventoryItems = await InventoryItem.find(dateFilter).sort({ date: -1 });

    let inputCgst = 0;
    let inputSgst = 0;
    const inventoryDetails = [];

    for (const item of inventoryItems) {
      const baseAmount = item.quantity * item.unitCost;
      const cgst = (baseAmount * (item.cgstPercent || 0)) / 100;
      const sgst = (baseAmount * (item.sgstPercent || 0)) / 100;
      inputCgst += cgst;
      inputSgst += sgst;

      inventoryDetails.push({
        id: item._id,
        name: item.name,
        quantity: item.quantity,
        unitCost: item.unitCost,
        baseAmount,
        cgstPercent: item.cgstPercent || 0,
        sgstPercent: item.sgstPercent || 0,
        cgstAmount: cgst,
        sgstAmount: sgst,
        totalGst: cgst + sgst,
        date: item.date,
        supplier: item.supplier,
      });
    }

    const totalInputGst = inputCgst + inputSgst;

    // ─── OUTPUT GST: from sales (completed products) ───
    const completedProducts = await CompletedProduct.find(dateFilter).sort({ date: -1 });

    let outputCgst = 0;
    let outputSgst = 0;
    const salesDetails = [];

    for (const cp of completedProducts) {
      const taxableAmount = cp.quantity * cp.sellingRate;
      const cgst = (taxableAmount * gst.cgstPercent) / 100;
      const sgst = (taxableAmount * gst.sgstPercent) / 100;
      outputCgst += cgst;
      outputSgst += sgst;

      salesDetails.push({
        id: cp._id,
        brandName: cp.brandName || 'Unbranded',
        quantity: cp.quantity,
        sellingRate: cp.sellingRate,
        taxableAmount,
        cgstPercent: gst.cgstPercent,
        sgstPercent: gst.sgstPercent,
        cgstAmount: cgst,
        sgstAmount: sgst,
        totalGst: cgst + sgst,
        date: cp.date,
        invoiceNumber: cp.invoiceNumber || '',
      });
    }

    const totalOutputGst = outputCgst + outputSgst;

    // ─── NET GST PAYABLE ───
    const netGstPayable = totalOutputGst - totalInputGst;

    return res.json({
      inputGst: {
        cgst: inputCgst,
        sgst: inputSgst,
        total: totalInputGst,
        itemCount: inventoryItems.length,
      },
      outputGst: {
        cgst: outputCgst,
        sgst: outputSgst,
        total: totalOutputGst,
        itemCount: completedProducts.length,
      },
      netGstPayable,
      isCredit: netGstPayable < 0,
      gstSettings: {
        cgstPercent: gst.cgstPercent,
        sgstPercent: gst.sgstPercent,
        companyName: gst.companyName,
        companyAddress: gst.companyAddress,
        companyPhone: gst.companyPhone,
        gstin: gst.gstin,
      },
      inventoryDetails,
      salesDetails,
      period: {
        startDate: startDate || null,
        endDate: endDate || null,
      },
      generatedAt: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({ message: 'Failed to calculate GST summary', error: error.message });
  }
});

export default router;
