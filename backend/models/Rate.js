import mongoose from 'mongoose';

const rateSchema = new mongoose.Schema(
  {
    category: { type: String, required: true, unique: true },
    amount: { type: Number, required: true },
  },
  { timestamps: true }
);

export default mongoose.model('Rate', rateSchema);


