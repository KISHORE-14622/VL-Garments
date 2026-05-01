import mongoose from 'mongoose';

const gstSettingSchema = new mongoose.Schema(
  {
    cgstPercent: { type: Number, required: true, default: 2.5 },
    sgstPercent: { type: Number, required: true, default: 2.5 },
    companyName: { type: String, default: 'Vijayalakshmi Garments' },
    companyAddress: { type: String, default: '' },
    companyPhone: { type: String, default: '' },
    gstin: { type: String, default: '' },
    lastInvoiceNumber: { type: Number, default: 0 },
    invoicePrefix: { type: String, default: 'VLG-' },
  },
  { timestamps: true }
);

export default mongoose.model('GstSetting', gstSettingSchema);
