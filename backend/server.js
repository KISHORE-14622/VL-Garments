// Global error handlers - must be first so we always see crash reasons
process.on('uncaughtException', (err) => {
  console.error('UNCAUGHT EXCEPTION:', err.message);
  console.error(err.stack);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  console.error('UNHANDLED REJECTION:', reason);
  process.exit(1);
});

import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env before anything else
const envResult = dotenv.config({ path: path.join(__dirname, '.env') });
if (envResult.error) {
  console.warn('Warning: Could not load .env file:', envResult.error.message);
}

console.log('Environment check:');
console.log('  PORT:', process.env.PORT || '(not set, will use 5000)');
console.log('  MONGODB_URI:', process.env.MONGODB_URI ? 'SET ✓' : 'NOT SET ✗');
console.log('  JWT_SECRET:', process.env.JWT_SECRET ? 'SET ✓' : 'NOT SET ✗');
console.log('  NODE_ENV:', process.env.NODE_ENV || '(not set)');

import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

import connectDB from './config/db.js';
import authRoutes from './routes/auth.js';
import productRoutes from './routes/products.js';
import rateRoutes from './routes/rates.js';
import productionRoutes from './routes/production.js';
import paymentRoutes from './routes/payments.js';
import inventoryRoutes from './routes/inventory.js';
import workerRoutes from './routes/workers.js';
import stitchEntryRoutes from './routes/stitchEntries.js';
import workerCategoryRoutes from './routes/workerCategories.js';
import attendanceRoutes from './routes/attendance.js';
import completedProductionRoutes from './routes/completedProduction.js';
import brandRoutes from './routes/brands.js';
import gstSettingsRoutes from './routes/gstSettings.js';
import billingRoutes from './routes/billing.js';
import gstSummaryRoutes from './routes/gstSummary.js';
import exportRoutes from './routes/exports.js';

const app = express();

// Core middleware
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/rates', rateRoutes);
app.use('/api/production', productionRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/workers', workerRoutes);
app.use('/api/stitch-entries', stitchEntryRoutes);
app.use('/api/worker-categories', workerCategoryRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/completed-production', completedProductionRoutes);
app.use('/api/brands', brandRoutes);
app.use('/api/gst-settings', gstSettingsRoutes);
app.use('/api/billing', billingRoutes);
app.use('/api/gst-summary', gstSummaryRoutes);
app.use('/api/exports', exportRoutes);

// Welcome route
app.get('/', (req, res) => {
  res.json({
    message: 'VL Garments API',
    status: 'running',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      products: '/api/products',
      workers: '/api/workers',
      production: '/api/production',
      payments: '/api/payments',
      inventory: '/api/inventory',
      stitchEntries: '/api/stitch-entries',
      workerCategories: '/api/worker-categories',
      rates: '/api/rates'
    }
  });
});

// Health check
app.get('/health', (req, res) => res.json({ ok: true }));

// Start
const PORT = process.env.PORT || 5000;
connectDB().then(() => {
  app.listen(PORT, () => console.log(`API listening on port ${PORT}`));
}).catch((err) => {
  console.error('Failed to start server:', err.message);
  process.exit(1);
});
