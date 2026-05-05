import mongoose from 'mongoose';

async function update() {
  await mongoose.connect('mongodb+srv://Viji:Kishore14622@vl-garments.hrspio9.mongodb.net/?appName=VL-Garments');
  const Worker = mongoose.model('Worker', new mongoose.Schema({ name: String, email: String }, { strict: false }));
  await Worker.updateOne({ name: 'Pushpa' }, { $set: { email: 'kishoresanthosh14622@gmail.com' } });
  await Worker.updateOne({ name: 'Kishore' }, { $set: { email: 'kishoresanthosh14622@gmail.com' } });
  console.log('Updated workers in DB');
  process.exit(0);
}

update().catch(console.error);
