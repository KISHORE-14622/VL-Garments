import express from 'express';
import StitchEntry from '../models/StitchEntry.js';
import Rate from '../models/Rate.js';
import Worker from '../models/Worker.js';

const router = express.Router();

// Get all stitch entries
router.get('/', async (req, res) => {
  try {
    console.log('📋 Fetching all stitch entries...');
    const entries = await StitchEntry.find()
      .sort({ date: -1 })
      .populate('workerId', 'name phoneNumber');
    
    console.log(`✅ Found ${entries.length} stitch entries`);
    res.json(entries);
  } catch (error) {
    console.error('❌ Error fetching stitch entries:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get stitch entries for a specific worker
router.get('/worker/:workerId', async (req, res) => {
  try {
    const { workerId } = req.params;
    console.log(`📋 Fetching stitch entries for worker: ${workerId}`);
    
    const entries = await StitchEntry.find({ workerId })
      .sort({ date: -1 })
      .populate('workerId', 'name phoneNumber');
    
    console.log(`✅ Found ${entries.length} entries for worker ${workerId}`);
    res.json(entries);
  } catch (error) {
    console.error('❌ Error fetching worker entries:', error);
    res.status(500).json({ error: error.message });
  }
});

// Add a new stitch entry
router.post('/', async (req, res) => {
  try {
    const { workerId, categoryId, quantity, date, staffId } = req.body;
    
    console.log('📝 Stitch entry request received:', { workerId, categoryId, quantity, date });
    
    // Validate required fields
    if (!workerId || !categoryId || !quantity) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Verify worker exists
    const worker = await Worker.findById(workerId);
    if (!worker) {
      console.log('❌ Worker not found:', workerId);
      return res.status(404).json({ error: 'Worker not found' });
    }
    
    // Create entry
    const entry = await StitchEntry.create({
      workerId,
      categoryId,
      quantity: parseInt(quantity),
      date: date ? new Date(date) : new Date(),
      staffId: staffId || null,
    });
    
    // Populate worker details
    await entry.populate('workerId', 'name phoneNumber');
    
    console.log(`✅ Stitch entry created successfully:`, {
      id: entry._id,
      worker: worker.name,
      category: categoryId,
      quantity: quantity,
    });
    
    res.status(201).json(entry);
  } catch (error) {
    console.error('❌ Error creating stitch entry:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get weekly statistics for all workers
router.get('/weekly-stats', async (req, res) => {
  try {
    console.log('📊 Calculating weekly statistics...');
    
    // Get entries from last 7 days
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);
    
    const entries = await StitchEntry.find({ date: { $gte: weekAgo } })
      .populate('workerId', 'name phoneNumber');
    
    // Get rates
    const rates = await Rate.find({});
    const rateMap = {};
    rates.forEach(rate => {
      rateMap[rate.category] = rate.amount;
    });
    
    // Calculate stats per worker
    const workerStats = {};
    entries.forEach(entry => {
      if (!entry.workerId) return;
      
      const workerId = entry.workerId._id.toString();
      if (!workerStats[workerId]) {
        workerStats[workerId] = {
          workerId: workerId,
          workerName: entry.workerId.name,
          workerPhone: entry.workerId.phoneNumber,
          totalQuantity: 0,
          totalEarnings: 0,
          entries: 0,
          categories: {},
        };
      }
      
      const rate = rateMap[entry.categoryId] || 0;
      const earnings = entry.quantity * rate;
      
      workerStats[workerId].totalQuantity += entry.quantity;
      workerStats[workerId].totalEarnings += earnings;
      workerStats[workerId].entries += 1;
      
      if (!workerStats[workerId].categories[entry.categoryId]) {
        workerStats[workerId].categories[entry.categoryId] = {
          quantity: 0,
          earnings: 0,
        };
      }
      
      workerStats[workerId].categories[entry.categoryId].quantity += entry.quantity;
      workerStats[workerId].categories[entry.categoryId].earnings += earnings;
    });
    
    const stats = Object.values(workerStats);
    console.log(`✅ Weekly stats calculated for ${stats.length} workers`);
    
    res.json({
      period: 'last_7_days',
      workers: stats,
      totalWorkers: stats.length,
      totalEntries: entries.length,
      totalRevenue: stats.reduce((sum, w) => sum + w.totalEarnings, 0),
    });
  } catch (error) {
    console.error('❌ Error calculating weekly stats:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get total revenue (all time)
router.get('/total-revenue', async (req, res) => {
  try {
    console.log('💰 Calculating total revenue...');
    
    const entries = await StitchEntry.find({});
    const rates = await Rate.find({});
    
    const rateMap = {};
    rates.forEach(rate => {
      rateMap[rate.category] = rate.amount;
    });
    
    let totalRevenue = 0;
    entries.forEach(entry => {
      const rate = rateMap[entry.categoryId] || 0;
      totalRevenue += entry.quantity * rate;
    });
    
    console.log(`✅ Total revenue: ₹${totalRevenue}`);
    
    res.json({
      totalRevenue,
      totalEntries: entries.length,
    });
  } catch (error) {
    console.error('❌ Error calculating total revenue:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete a stitch entry (for corrections)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    console.log(`🗑️ Deleting stitch entry: ${id}`);
    
    const entry = await StitchEntry.findByIdAndDelete(id);
    
    if (!entry) {
      return res.status(404).json({ error: 'Entry not found' });
    }
    
    console.log('✅ Entry deleted successfully');
    res.json({ message: 'Entry deleted successfully' });
  } catch (error) {
    console.error('❌ Error deleting entry:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
