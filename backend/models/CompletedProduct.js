import mongoose from 'mongoose';

const completedProductSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    quantity: { type: Number, required: true },
    sellingRate: { type: Number, required: true },
    costPerUnit: { type: Number, required: true },
    brandName: { type: String, default: '' },
    notes: { type: String, default: '' },
    invoiceNumber: { type: String, default: '' },
  },
  { timestamps: true }
);

export default mongoose.model('CompletedProduct', completedProductSchema);
