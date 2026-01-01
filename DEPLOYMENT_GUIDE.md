# VL-Garments Deployment Guide for Render

## Overview
This project consists of:
- **Backend**: Node.js/Express API (in `backend/` folder)
- **Frontend**: Flutter Web App (in `my_app/` folder)
- **Database**: MongoDB (use MongoDB Atlas)

You need to deploy **TWO separate services** on Render.

---

## Prerequisites

Before deploying, gather these credentials:

1. **MongoDB Connection String**
   - Sign up at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
   - Create a free cluster
   - Get connection string (format: `mongodb+srv://username:password@cluster.mongodb.net/dbname`)

2. **JWT Secret**
   - Generate a random secure string (e.g., use: `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"`)

3. **Razorpay Credentials** (if using payments)
   - Get from [Razorpay Dashboard](https://dashboard.razorpay.com/)
   - Key ID and Key Secret

---

## Part 1: Deploy Backend (Web Service)

### Step 1: Create Web Service on Render

1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository: `KISHORE-14622/VL-Garments`

### Step 2: Configure Backend Service

Fill in these details:

| Field | Value |
|-------|-------|
| **Name** | `vl-garments-backend` (or any unique name) |
| **Region** | Choose closest to your users |
| **Branch** | `main` |
| **Root Directory** | `backend` |
| **Runtime** | `Node` |
| **Build Command** | `npm install` |
| **Start Command** | `npm start` |
| **Instance Type** | `Free` (or paid if needed) |

### Step 3: Add Environment Variables

Click **"Advanced"** and add these environment variables:

| Name | Value | Notes |
|------|-------|-------|
| `MONGODB_URI` | `mongodb+srv://...` | Your MongoDB Atlas connection string |
| `JWT_SECRET` | `your-random-secret-key` | Generate a secure random string |
| `RAZORPAY_KEY_ID` | `rzp_test_...` or `rzp_live_...` | From Razorpay dashboard |
| `RAZORPAY_KEY_SECRET` | `your-razorpay-secret` | From Razorpay dashboard |
| `PORT` | `10000` | Render uses port 10000 by default |
| `NODE_ENV` | `production` | Sets production mode |

### Step 4: Deploy Backend

1. Click **"Create Web Service"**
2. Wait for deployment (5-10 minutes)
3. Note your backend URL: `https://vl-garments-backend.onrender.com`

---

## Part 2: Deploy Frontend (Static Site)

### Step 1: Build Flutter Web (Already Done ✅)

You've already built the Flutter web app. The static files are in:
```
my_app/build/web/
```

### Step 2: Update API Endpoint in Flutter

Before deploying, update your Flutter app to use the production backend URL:

1. Find your API configuration file (usually in `lib/config/` or `lib/services/`)
2. Update the base URL to your Render backend URL:
   ```dart
   // Example:
   static const String baseUrl = 'https://vl-garments-backend.onrender.com/api';
   ```
3. Rebuild: `flutter build web --release`

### Step 3: Create Static Site on Render

1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click **"New +"** → **"Static Site"**
3. Connect your GitHub repository: `KISHORE-14622/VL-Garments`

### Step 4: Configure Frontend Service

Fill in these details:

| Field | Value |
|-------|-------|
| **Name** | `vl-garments` (or any unique name) |
| **Branch** | `main` |
| **Root Directory** | `my_app` |
| **Build Command** | `flutter build web --release` |
| **Publish Directory** | `build/web` |

### Step 5: Add Environment Variables (if needed)

If your Flutter app uses environment variables (e.g., from `.env` file):

| Name | Value |
|------|-------|
| `API_URL` | `https://vl-garments-backend.onrender.com` |

### Step 6: Deploy Frontend

1. Click **"Create Static Site"**
2. Wait for deployment (5-10 minutes)
3. Your site will be live at: `https://vl-garments.onrender.com`

---

## Part 3: Post-Deployment Configuration

### Update CORS in Backend

Your backend needs to allow requests from your frontend domain:

1. Edit `backend/server.js`
2. Update CORS configuration:
   ```javascript
   app.use(cors({
     origin: [
       'https://vl-garments.onrender.com',  // Your frontend URL
       'http://localhost:3000'               // For local development
     ],
     credentials: true
   }));
   ```
3. Commit and push changes (Render will auto-redeploy)

### Initialize Database

If you need to initialize rates or staff data:

1. Go to your backend service on Render
2. Open the **Shell** tab
3. Run initialization commands:
   ```bash
   npm run init-rates
   npm run migrate-staff
   ```

---

## Quick Reference: Deployment Settings

### Backend (Web Service)
```
Name: vl-garments-backend
Root Directory: backend
Build Command: npm install
Start Command: npm start
Publish Directory: (leave empty)
```

**Environment Variables:**
```
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/vl-garments
JWT_SECRET=<generate-random-64-char-string>
RAZORPAY_KEY_ID=rzp_test_xxxxx
RAZORPAY_KEY_SECRET=xxxxx
PORT=10000
NODE_ENV=production
```

### Frontend (Static Site)
```
Name: vl-garments
Root Directory: my_app
Build Command: flutter build web --release
Publish Directory: build/web
```

---

## Troubleshooting

### Backend Issues

**Problem**: Backend won't start
- Check environment variables are set correctly
- Check MongoDB connection string is valid
- View logs in Render dashboard

**Problem**: Database connection fails
- Whitelist Render's IP in MongoDB Atlas (or allow all: `0.0.0.0/0`)
- Check MongoDB URI format

### Frontend Issues

**Problem**: API calls fail
- Check backend URL is correct in Flutter config
- Check CORS is configured properly
- Rebuild Flutter web after changing API URL

**Problem**: Build fails
- Ensure Flutter is installed in Render (it should auto-detect)
- Check build logs for specific errors

---

## Custom Domain (Optional)

To use your own domain:

1. Go to your service settings on Render
2. Click **"Custom Domain"**
3. Add your domain (e.g., `vlgarments.com`)
4. Update DNS records as instructed by Render

---

## Monitoring & Maintenance

- **Logs**: View real-time logs in Render dashboard
- **Metrics**: Monitor CPU, memory, bandwidth usage
- **Auto-Deploy**: Render auto-deploys when you push to `main` branch
- **Free Tier Limits**: 
  - Backend spins down after 15 min of inactivity
  - First request after spin-down takes ~30 seconds

---

## Cost Estimate

- **Backend**: Free tier (or $7/month for always-on)
- **Frontend**: Free (static sites are always free)
- **MongoDB Atlas**: Free tier (512MB storage)
- **Total**: $0/month (with limitations) or ~$7/month (production-ready)

---

## Next Steps

1. ✅ Build Flutter web (DONE)
2. ⬜ Get MongoDB Atlas connection string
3. ⬜ Generate JWT secret
4. ⬜ Deploy backend to Render
5. ⬜ Update Flutter API URL
6. ⬜ Rebuild Flutter web
7. ⬜ Deploy frontend to Render
8. ⬜ Update CORS settings
9. ⬜ Test the deployed application

---

## Support

If you encounter issues:
- Check [Render Documentation](https://render.com/docs)
- View deployment logs in Render dashboard
- Check MongoDB Atlas network access settings

Good luck with your deployment! 🚀
