import mongoose from 'mongoose';

const inventoryTypeSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, unique: true },
  },
  { timestamps: true }
);

export default mongoose.model('InventoryType', inventoryTypeSchema);
