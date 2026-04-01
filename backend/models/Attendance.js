import mongoose from 'mongoose';

const attendanceSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    worker: { type: mongoose.Schema.Types.ObjectId, ref: 'Worker', required: true },
    status: { type: String, enum: ['present', 'absent', 'half-day'], default: 'present' },
    notes: { type: String },
  },
  { timestamps: true }
);

// One attendance record per worker per day
attendanceSchema.index({ date: 1, worker: 1 }, { unique: true });

export default mongoose.model('Attendance', attendanceSchema);
