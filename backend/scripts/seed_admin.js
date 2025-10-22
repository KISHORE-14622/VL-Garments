import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';

import connectDB from '../config/db.js';
import User from '../models/User.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '..', '.env') });

async function main() {
  const email = process.env.SEED_ADMIN_EMAIL || 'admin14622@gmail.com';
  const password = process.env.SEED_ADMIN_PASSWORD || 'Admin@123';
  const name = process.env.SEED_ADMIN_NAME || 'Administrator';

  if (!process.env.MONGODB_URI) {
    console.error('MONGODB_URI not set in backend/.env');
    process.exit(1);
  }

  await connectDB();

  const existing = await User.findOne({ email });
  if (existing) {
    console.log(`Admin user already exists: ${email} (id=${existing._id})`);
    process.exit(0);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await User.create({ name, email, passwordHash, role: 'admin' });
  console.log(`Admin user created: ${email} (id=${user._id})`);
  process.exit(0);
}

main().catch((err) => {
  console.error('Failed to seed admin:', err);
  process.exit(1);
});
