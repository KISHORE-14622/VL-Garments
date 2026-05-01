import mongoose from 'mongoose';

const inventoryItemSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    quantity: { type: Number, required: true },
    unitCost: { type: Number, required: true },
    cgstPercent: { type: Number, default: 0 },
    sgstPercent: { type: Number, default: 0 },
    supplier: { type: String, default: '' },
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    date: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

export default mongoose.model('InventoryItem', inventoryItemSchema);
