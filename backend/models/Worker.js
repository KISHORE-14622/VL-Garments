import mongoose from 'mongoose';

const workerSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    phoneNumber: { type: String, required: true },
    email: { type: String },
    joinedDate: { type: Date, default: Date.now },
    isActive: { type: Boolean, default: true },
    address: { type: String },
    notes: { type: String },
    category: { type: mongoose.Schema.Types.ObjectId, ref: 'WorkerCategory' },
  },
  { timestamps: true }
);

export default mongoose.model('Worker', workerSchema);
