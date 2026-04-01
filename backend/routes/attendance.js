import express from 'express';
import Attendance from '../models/Attendance.js';
import { authRequired } from '../middleware/auth.js';

const router = express.Router();

// GET /api/attendance?date=YYYY-MM-DD  — get attendance for a specific date
router.get('/', authRequired, async (req, res) => {
  try {
    const { date } = req.query;
    const filter = {};
    if (date) {
      const d = new Date(date);
      const start = new Date(d.getFullYear(), d.getMonth(), d.getDate());
      const end = new Date(start);
      end.setDate(end.getDate() + 1);
      filter.date = { $gte: start, $lt: end };
    }
    const records = await Attendance.find(filter)
      .populate('worker', 'name phoneNumber category')
      .sort({ date: -1, createdAt: -1 });
    res.json(records);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST /api/attendance — mark attendance (single or bulk)
router.post('/', authRequired, async (req, res) => {
  try {
    const { date, workers, status, notes } = req.body;
    // workers is an array of worker IDs
    if (!date || !workers || !Array.isArray(workers) || workers.length === 0) {
      return res.status(400).json({ message: 'date and workers[] are required' });
    }

    const d = new Date(date);
    const dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate());

    const results = [];
    for (const workerId of workers) {
      const record = await Attendance.findOneAndUpdate(
        { date: dayStart, worker: workerId },
        { date: dayStart, worker: workerId, status: status || 'present', notes: notes || '' },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
      results.push(record);
    }

    // Populate and return
    const populated = await Attendance.find({
      _id: { $in: results.map(r => r._id) }
    }).populate('worker', 'name phoneNumber category');

    res.status(201).json(populated);
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ message: 'Duplicate attendance entry' });
    }
    res.status(500).json({ message: err.message });
  }
});

// PUT /api/attendance/:id — update status
router.put('/:id', authRequired, async (req, res) => {
  try {
    const { status, notes } = req.body;
    const record = await Attendance.findByIdAndUpdate(
      req.params.id,
      { status, notes },
      { new: true }
    ).populate('worker', 'name phoneNumber category');
    if (!record) return res.status(404).json({ message: 'Not found' });
    res.json(record);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// DELETE /api/attendance/:id — remove attendance record
router.delete('/:id', authRequired, async (req, res) => {
  try {
    await Attendance.findByIdAndDelete(req.params.id);
    res.json({ message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

export default router;
