import mongoose from 'mongoose';

const brandSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, unique: true },
    sellingRate: { type: Number, required: true },
    costPerUnit: { type: Number, required: true },
  },
  { timestamps: true }
);

export default mongoose.model('Brand', brandSchema);
