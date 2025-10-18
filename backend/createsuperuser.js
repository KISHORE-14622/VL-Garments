import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import User from './models/User.js';

dotenv.config({ path: './backend/.env' });

const createSuperUser = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    const adminEmail = 'admin@example.com';
    const adminPassword = 'password';

    const existingAdmin = await User.findOne({ email: adminEmail });

    if (existingAdmin) {
      console.log('Admin user already exists.');
      mongoose.connection.close();
      return;
    }

    const passwordHash = await bcrypt.hash(adminPassword, 10);

    await User.create({
      name: 'Admin',
      email: adminEmail,
      passwordHash,
      role: 'admin',
    });

    console.log('Admin user created successfully.');
    console.log(`Email: ${adminEmail}`);
    console.log(`Password: ${adminPassword}`);

    mongoose.connection.close();
  } catch (error) {
    console.error('Error creating admin user:', error);
    mongoose.connection.close();
  }
};

createSuperUser();
