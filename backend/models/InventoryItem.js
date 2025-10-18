import mongoose from 'mongoose';

const inventoryItemSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    quantity: { type: Number, required: true },
    unitCost: { type: Number, required: true },
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // optional per-staff tracking
    date: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

export default mongoose.model('InventoryItem', inventoryItemSchema);


