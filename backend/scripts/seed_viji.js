import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';
import mongoose from 'mongoose';

import connectDB from '../config/db.js';
import User from '../models/User.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '..', '.env') });

async function main() {
  const email = 'vijisanthosh14622@gmail.com';
  const password = 'svka14622';
  const name = 'Viji Santhosh';

  if (!process.env.MONGODB_URI) {
    console.error('MONGODB_URI not set in backend/.env');
    process.exit(1);
  }

  await connectDB();

  const existing = await User.findOne({ email });
  if (existing) {
    console.log(`User already exists: ${email}. Updating password...`);
    const passwordHash = await bcrypt.hash(password, 10);
    existing.passwordHash = passwordHash;
    await existing.save();
    console.log('Password updated successfully.');
    process.exit(0);
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await User.create({ name, email, passwordHash, role: 'admin' });
  console.log(`User created: ${email} (id=${user._id})`);
  process.exit(0);
}

main().catch((err) => {
  console.error('Failed to seed user:', err);
  process.exit(1);
});
