import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env before anything else
const envResult = dotenv.config({ path: path.join(__dirname, '.env') });
if (envResult.error) {
  console.warn('Warning: Could not load .env file (using Render environment variables)');
}

console.log('=== VL Garments Backend Starting ===');
console.log('Environment check:');
console.log('  PORT:', process.env.PORT || '(not set, will use 5000)');
console.log('  MONGODB_URI:', process.env.MONGODB_URI ? 'SET ✓' : 'NOT SET ✗');
console.log('  JWT_SECRET:', process.env.JWT_SECRET ? 'SET ✓' : 'NOT SET ✗');
console.log('  NODE_ENV:', process.env.NODE_ENV || '(not set)');

async function startServer() {
  try {
    console.log('Loading modules...');

    const { default: express } = await import('express');
    const { default: cors } = await import('cors');
    const { default: morgan } = await import('morgan');
    const { default: connectDB } = await import('./config/db.js');

    console.log('Loading routes...');
    const { default: authRoutes } = await import('./routes/auth.js');
    const { default: productRoutes } = await import('./routes/products.js');
    const { default: rateRoutes } = await import('./routes/rates.js');
    const { default: productionRoutes } = await import('./routes/production.js');
    const { default: paymentRoutes } = await import('./routes/payments.js');
    const { default: inventoryRoutes } = await import('./routes/inventory.js');
    const { default: workerRoutes } = await import('./routes/workers.js');
    const { default: stitchEntryRoutes } = await import('./routes/stitchEntries.js');
    const { default: workerCategoryRoutes } = await import('./routes/workerCategories.js');
    const { default: attendanceRoutes } = await import('./routes/attendance.js');
    const { default: completedProductionRoutes } = await import('./routes/completedProduction.js');
    const { default: brandRoutes } = await import('./routes/brands.js');
    const { default: gstSettingsRoutes } = await import('./routes/gstSettings.js');
    const { default: billingRoutes } = await import('./routes/billing.js');
    const { default: gstSummaryRoutes } = await import('./routes/gstSummary.js');
    const { default: exportRoutes } = await import('./routes/exports.js');

    console.log('All modules loaded ✓');

    const app = express();

    // CORS - allow all origins (Flutter web + APK + Render frontend)
    const corsOptions = {
      origin: '*',
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
      credentials: false,
    };
    app.use(cors(corsOptions));
    app.options('*', cors(corsOptions)); // Handle preflight for all routes

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

    // Connect to MongoDB and start listening
    const PORT = process.env.PORT || 5000;
    console.log('Connecting to MongoDB...');
    await connectDB();
    app.listen(PORT, () => console.log(`✓ API listening on port ${PORT}`));

  } catch (err) {
    console.error('=== STARTUP ERROR ===');
    console.error('Message:', err.message);
    console.error('Stack:', err.stack);
    process.exit(1);
  }
}

startServer();
