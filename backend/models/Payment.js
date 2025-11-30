import mongoose from 'mongoose';

const paymentSchema = new mongoose.Schema(
  {
    staff: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    periodStart: { type: Date, required: true },
    periodEnd: { type: Date, required: true },
    amount: { type: Number, required: true },
    status: { type: String, enum: ['pending', 'paid'], default: 'pending' },
    paymentMethod: { type: String, enum: ['cash', 'razorpay'], default: null },
    razorpayPaymentId: { type: String, default: null },
    razorpayOrderId: { type: String, default: null },
    razorpaySignature: { type: String, default: null },
  },
  { timestamps: true }
);

export default mongoose.model('Payment', paymentSchema);


