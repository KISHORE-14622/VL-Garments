import express from 'express';
import ExcelJS from 'exceljs';
import InventoryItem from '../models/InventoryItem.js';
import CompletedProduct from '../models/CompletedProduct.js';
import GstSetting from '../models/GstSetting.js';
import Brand from '../models/Brand.js';
import Worker from '../models/Worker.js';

const router = express.Router();

// ═══ Helper: Build date filter ═══
function buildDateFilter(startDate, endDate) {
  const filter = {};
  if (startDate || endDate) {
    filter.date = {};
    if (startDate) filter.date.$gte = new Date(startDate);
    if (endDate) filter.date.$lte = new Date(endDate);
  }
  return filter;
}

// ═══ Helper: Style header row ═══
function styleHeaderRow(worksheet) {
  const headerRow = worksheet.getRow(1);
  headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11 };
  headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF4A90E2' } };
  headerRow.alignment = { horizontal: 'center', vertical: 'middle' };
  headerRow.height = 28;

  // Auto-width columns
  worksheet.columns.forEach((column) => {
    let maxLen = column.header ? column.header.length : 10;
    column.eachCell({ includeEmpty: false }, (cell) => {
      const val = cell.value ? cell.value.toString() : '';
      if (val.length > maxLen) maxLen = val.length;
    });
    column.width = Math.min(maxLen + 4, 40);
  });
}

// ═══ Helper: Add summary row ═══
function addSummaryRow(worksheet, label, values) {
  const row = worksheet.addRow([label, ...values]);
  row.font = { bold: true, size: 11 };
  row.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF0F4FF' } };
  return row;
}

// ═══ Helper: Format date ═══
function fmtDate(d) {
  if (!d) return '';
  const dt = new Date(d);
  return `${dt.getDate().toString().padStart(2, '0')}/${(dt.getMonth() + 1).toString().padStart(2, '0')}/${dt.getFullYear()}`;
}

// ═══════════════════════════════════════
//  1. GST Billing Export
// ═══════════════════════════════════════
router.get('/gst-billing', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const filter = buildDateFilter(startDate, endDate);

    let gst = await GstSetting.findOne();
    if (!gst) gst = await GstSetting.create({ cgstPercent: 2.5, sgstPercent: 2.5 });

    const entries = await CompletedProduct.find(filter).sort({ date: -1 });
    const inventoryItems = await InventoryItem.find(filter).sort({ date: -1 });

    const workbook = new ExcelJS.Workbook();
    workbook.creator = gst.companyName || 'VL Garments';

    // ─── Sheet 1: Sales Bills ───
    const billSheet = workbook.addWorksheet('Sales Bills');
    billSheet.columns = [
      { header: 'Invoice #', key: 'invoice' },
      { header: 'Date', key: 'date' },
      { header: 'Brand', key: 'brand' },
      { header: 'Qty', key: 'qty' },
      { header: 'Selling Rate (₹)', key: 'rate' },
      { header: 'Taxable Amount (₹)', key: 'taxable' },
      { header: `CGST @${gst.cgstPercent}% (₹)`, key: 'cgst' },
      { header: `SGST @${gst.sgstPercent}% (₹)`, key: 'sgst' },
      { header: 'Total GST (₹)', key: 'totalGst' },
      { header: 'Grand Total (₹)', key: 'grand' },
    ];

    let totalTaxable = 0, totalCgst = 0, totalSgst = 0, totalGrand = 0;

    for (const entry of entries) {
      const taxable = entry.quantity * entry.sellingRate;
      const cgst = (taxable * gst.cgstPercent) / 100;
      const sgst = (taxable * gst.sgstPercent) / 100;
      totalTaxable += taxable;
      totalCgst += cgst;
      totalSgst += sgst;
      totalGrand += taxable + cgst + sgst;

      billSheet.addRow({
        invoice: entry.invoiceNumber || '-',
        date: fmtDate(entry.date),
        brand: entry.brandName || 'Unbranded',
        qty: entry.quantity,
        rate: entry.sellingRate,
        taxable: +taxable.toFixed(2),
        cgst: +cgst.toFixed(2),
        sgst: +sgst.toFixed(2),
        totalGst: +(cgst + sgst).toFixed(2),
        grand: +(taxable + cgst + sgst).toFixed(2),
      });
    }

    addSummaryRow(billSheet, 'TOTAL', [
      '', '', '', '', +totalTaxable.toFixed(2), +totalCgst.toFixed(2),
      +totalSgst.toFixed(2), +(totalCgst + totalSgst).toFixed(2), +totalGrand.toFixed(2),
    ]);
    styleHeaderRow(billSheet);

    // ─── Sheet 2: GST Payable Summary ───
    const summarySheet = workbook.addWorksheet('GST Payable Summary');
    summarySheet.columns = [
      { header: 'Description', key: 'desc', width: 35 },
      { header: 'CGST (₹)', key: 'cgst', width: 15 },
      { header: 'SGST (₹)', key: 'sgst', width: 15 },
      { header: 'Total (₹)', key: 'total', width: 18 },
    ];

    // Calculate input GST
    let inCgst = 0, inSgst = 0;
    for (const item of inventoryItems) {
      const base = item.quantity * item.unitCost;
      inCgst += (base * (item.cgstPercent || 0)) / 100;
      inSgst += (base * (item.sgstPercent || 0)) / 100;
    }

    const outCgst = totalCgst;
    const outSgst = totalSgst;
    const netCgst = outCgst - inCgst;
    const netSgst = outSgst - inSgst;

    summarySheet.addRow({ desc: 'Output GST (on Sales)', cgst: +outCgst.toFixed(2), sgst: +outSgst.toFixed(2), total: +(outCgst + outSgst).toFixed(2) });
    summarySheet.addRow({ desc: 'Less: Input GST (on Purchases)', cgst: +inCgst.toFixed(2), sgst: +inSgst.toFixed(2), total: +(inCgst + inSgst).toFixed(2) });
    summarySheet.addRow({});

    const netRow = summarySheet.addRow({ desc: 'NET GST PAYABLE', cgst: +netCgst.toFixed(2), sgst: +netSgst.toFixed(2), total: +(netCgst + netSgst).toFixed(2) });
    netRow.font = { bold: true, size: 12 };
    netRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: (netCgst + netSgst) >= 0 ? 'FFFFF0F0' : 'FFF0FFF0' } };

    if (netCgst + netSgst < 0) {
      summarySheet.addRow({});
      summarySheet.addRow({ desc: 'NOTE: Negative value indicates Input Tax Credit (ITC)' });
    }
    styleHeaderRow(summarySheet);

    // ─── Sheet 3: Purchase GST Details ───
    const purchaseSheet = workbook.addWorksheet('Purchase GST (Input)');
    purchaseSheet.columns = [
      { header: 'Date', key: 'date' },
      { header: 'Item Name', key: 'name' },
      { header: 'Supplier', key: 'supplier' },
      { header: 'Qty', key: 'qty' },
      { header: 'Unit Cost (₹)', key: 'cost' },
      { header: 'Base Amount (₹)', key: 'base' },
      { header: 'CGST %', key: 'cgstPct' },
      { header: 'CGST (₹)', key: 'cgst' },
      { header: 'SGST %', key: 'sgstPct' },
      { header: 'SGST (₹)', key: 'sgst' },
      { header: 'Total with GST (₹)', key: 'grand' },
    ];

    for (const item of inventoryItems) {
      const base = item.quantity * item.unitCost;
      const cg = (base * (item.cgstPercent || 0)) / 100;
      const sg = (base * (item.sgstPercent || 0)) / 100;
      purchaseSheet.addRow({
        date: fmtDate(item.date),
        name: item.name,
        supplier: item.supplier || '-',
        qty: item.quantity,
        cost: item.unitCost,
        base: +base.toFixed(2),
        cgstPct: item.cgstPercent || 0,
        cgst: +cg.toFixed(2),
        sgstPct: item.sgstPercent || 0,
        sgst: +sg.toFixed(2),
        grand: +(base + cg + sg).toFixed(2),
      });
    }
    styleHeaderRow(purchaseSheet);

    // Send file
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=GST_Billing_Report.xlsx');
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    return res.status(500).json({ message: 'Failed to export GST billing', error: error.message });
  }
});

// ═══════════════════════════════════════
//  2. Revenue Export
// ═══════════════════════════════════════
router.get('/revenue', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const filter = buildDateFilter(startDate, endDate);
    const entries = await CompletedProduct.find(filter).sort({ date: -1 });

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Revenue Report');
    sheet.columns = [
      { header: 'Date', key: 'date' },
      { header: 'Brand', key: 'brand' },
      { header: 'Invoice #', key: 'invoice' },
      { header: 'Quantity', key: 'qty' },
      { header: 'Selling Rate (₹)', key: 'rate' },
      { header: 'Cost/Unit (₹)', key: 'cost' },
      { header: 'Revenue (₹)', key: 'revenue' },
      { header: 'Total Cost (₹)', key: 'totalCost' },
      { header: 'Profit (₹)', key: 'profit' },
    ];

    let totalRev = 0, totalCost = 0, totalProfit = 0;

    for (const cp of entries) {
      const revenue = cp.quantity * cp.sellingRate;
      const cost = cp.quantity * cp.costPerUnit;
      const profit = revenue - cost;
      totalRev += revenue;
      totalCost += cost;
      totalProfit += profit;

      sheet.addRow({
        date: fmtDate(cp.date),
        brand: cp.brandName || 'Unbranded',
        invoice: cp.invoiceNumber || '-',
        qty: cp.quantity,
        rate: cp.sellingRate,
        cost: cp.costPerUnit,
        revenue: +revenue.toFixed(2),
        totalCost: +cost.toFixed(2),
        profit: +profit.toFixed(2),
      });
    }

    addSummaryRow(sheet, 'TOTAL', ['', '', '', '', '', +totalRev.toFixed(2), +totalCost.toFixed(2), +totalProfit.toFixed(2)]);
    styleHeaderRow(sheet);

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=Revenue_Report.xlsx');
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    return res.status(500).json({ message: 'Failed to export revenue', error: error.message });
  }
});

// ═══════════════════════════════════════
//  3. Production Export
// ═══════════════════════════════════════
router.get('/production', async (req, res) => {
  try {
    // Use dynamic import for the Production model
    const { default: Production } = await import('../models/Production.js');
    const workers = await Worker.find();
    const workerMap = {};
    for (const w of workers) workerMap[w._id.toString()] = w.name;

    const { startDate, endDate } = req.query;
    const filter = buildDateFilter(startDate, endDate);
    const entries = await Production.find(filter).sort({ date: -1 });

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Production Report');
    sheet.columns = [
      { header: 'Date', key: 'date' },
      { header: 'Worker', key: 'worker' },
      { header: 'Category', key: 'category' },
      { header: 'Quantity', key: 'qty' },
    ];

    let totalQty = 0;

    for (const entry of entries) {
      const workerId = entry.worker ? entry.worker.toString() : '';
      totalQty += entry.quantity;
      sheet.addRow({
        date: fmtDate(entry.date),
        worker: workerMap[workerId] || 'Unknown',
        category: entry.category || '',
        qty: entry.quantity,
      });
    }

    addSummaryRow(sheet, 'TOTAL', ['', '', totalQty]);
    styleHeaderRow(sheet);

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=Production_Report.xlsx');
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    return res.status(500).json({ message: 'Failed to export production', error: error.message });
  }
});

// ═══════════════════════════════════════
//  4. Inventory Export
// ═══════════════════════════════════════
router.get('/inventory', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const filter = buildDateFilter(startDate, endDate);
    const items = await InventoryItem.find(filter).sort({ date: -1 });

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Inventory Report');
    sheet.columns = [
      { header: 'Date', key: 'date' },
      { header: 'Item Name', key: 'name' },
      { header: 'Supplier', key: 'supplier' },
      { header: 'Quantity', key: 'qty' },
      { header: 'Unit Cost (₹)', key: 'cost' },
      { header: 'Base Total (₹)', key: 'base' },
      { header: 'CGST %', key: 'cgstPct' },
      { header: 'CGST (₹)', key: 'cgst' },
      { header: 'SGST %', key: 'sgstPct' },
      { header: 'SGST (₹)', key: 'sgst' },
      { header: 'Grand Total (₹)', key: 'grand' },
    ];

    let totalBase = 0, totalGst = 0, totalGrand = 0;

    for (const item of items) {
      const base = item.quantity * item.unitCost;
      const cg = (base * (item.cgstPercent || 0)) / 100;
      const sg = (base * (item.sgstPercent || 0)) / 100;
      totalBase += base;
      totalGst += cg + sg;
      totalGrand += base + cg + sg;

      sheet.addRow({
        date: fmtDate(item.date),
        name: item.name,
        supplier: item.supplier || '-',
        qty: item.quantity,
        cost: item.unitCost,
        base: +base.toFixed(2),
        cgstPct: item.cgstPercent || 0,
        cgst: +cg.toFixed(2),
        sgstPct: item.sgstPercent || 0,
        sgst: +sg.toFixed(2),
        grand: +(base + cg + sg).toFixed(2),
      });
    }

    addSummaryRow(sheet, 'TOTAL', ['', '', '', +totalBase.toFixed(2), '', +totalGst.toFixed(2), '', +totalGst.toFixed(2), +(totalGrand).toFixed(2)]);
    styleHeaderRow(sheet);

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=Inventory_Report.xlsx');
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    return res.status(500).json({ message: 'Failed to export inventory', error: error.message });
  }
});

// ═══════════════════════════════════════
//  5. Payments Export
// ═══════════════════════════════════════
router.get('/payments', async (req, res) => {
  try {
    const { default: Payment } = await import('../models/Payment.js');
    const workers = await Worker.find();
    const workerMap = {};
    for (const w of workers) workerMap[w._id.toString()] = w.name;

    const payments = await Payment.find().sort({ createdAt: -1 });

    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet('Payment Report');
    sheet.columns = [
      { header: 'Date', key: 'date' },
      { header: 'Worker', key: 'worker' },
      { header: 'Amount (₹)', key: 'amount' },
      { header: 'Period Start', key: 'start' },
      { header: 'Period End', key: 'end' },
      { header: 'Status', key: 'status' },
      { header: 'Method', key: 'method' },
    ];

    let totalAmount = 0;

    for (const p of payments) {
      const workerId = p.worker ? p.worker.toString() : '';
      totalAmount += p.amount || 0;
      sheet.addRow({
        date: fmtDate(p.createdAt),
        worker: workerMap[workerId] || 'Unknown',
        amount: p.amount || 0,
        start: fmtDate(p.periodStart),
        end: fmtDate(p.periodEnd),
        status: p.status || 'pending',
        method: p.paymentMethod || '-',
      });
    }

    addSummaryRow(sheet, 'TOTAL', ['', +totalAmount.toFixed(2), '', '', '', '']);
    styleHeaderRow(sheet);

    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', 'attachment; filename=Payment_Report.xlsx');
    await workbook.xlsx.write(res);
    res.end();
  } catch (error) {
    return res.status(500).json({ message: 'Failed to export payments', error: error.message });
  }
});

export default router;
