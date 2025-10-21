import mongoose from 'mongoose';

const stitchEntrySchema = new mongoose.Schema(
  {
    workerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Worker', required: true },
    categoryId: { type: String, required: true },
    quantity: { type: Number, required: true, min: 1 },
    date: { type: Date, required: true, default: Date.now },
    staffId: { type: mongoose.Schema.Types.ObjectId, ref: 'Staff' }, // Who added this entry
  },
  { timestamps: true }
);

// Index for faster queries
stitchEntrySchema.index({ workerId: 1, date: -1 });
stitchEntrySchema.index({ date: -1 });

export default mongoose.model('StitchEntry', stitchEntrySchema);
