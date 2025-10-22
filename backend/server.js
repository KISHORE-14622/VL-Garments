import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.join(__dirname, '.env') });

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
import staffRoutes from './routes/staff.js';
import workerRoutes from './routes/workers.js';
import stitchEntryRoutes from './routes/stitchEntries.js';
import workerCategoryRoutes from './routes/workerCategories.js';

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
app.use('/api/staff', staffRoutes);
app.use('/api/workers', workerRoutes);
app.use('/api/stitch-entries', stitchEntryRoutes);
app.use('/api/worker-categories', workerCategoryRoutes);

// Health check
app.get('/health', (req, res) => res.json({ ok: true }));

// Start
const PORT = process.env.PORT || 5000;
connectDB().then(() => {
  app.listen(PORT, () => console.log(`API listening on port ${PORT}`));
});
