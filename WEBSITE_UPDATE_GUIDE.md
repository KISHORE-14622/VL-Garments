# Website Update Guide

## Problem
Your mobile app updates automatically when you build a new APK, but your website doesn't update because the `frontend/` directory contains old static files that aren't being rebuilt.

## Solution Overview

You have two options to keep your website updated:

---

## Option 1: Automatic Deployment (RECOMMENDED) ✅

I've updated your `render.yaml` file to automatically deploy both backend and frontend when you push to GitHub.

### What Changed:
- Added a new static site service for the Flutter web frontend
- Render will now automatically rebuild your website using `build.sh`
- Both backend and frontend will deploy together

### Steps to Enable:
1. **Commit the updated render.yaml:**
   ```bash
   git add render.yaml
   git commit -m "Add frontend auto-deployment to render.yaml"
   git push
   ```

2. **On Render Dashboard:**
   - Go to https://dashboard.render.com/
   - You should see a new service being created: `vl-garments-frontend`
   - Wait for it to deploy (5-10 minutes)
   - Your website will be at: `https://vl-garments-frontend.onrender.com`

3. **Update CORS in Backend:**
   Add the new frontend URL to your backend's CORS settings in `backend/server.js`:
   ```javascript
   app.use(cors({
     origin: [
       'https://vl-garments-frontend.onrender.com',
       'http://localhost:3000'
     ],
     credentials: true
   }));
   ```

### Future Updates:
From now on, whenever you push code to GitHub:
- ✅ Backend will auto-deploy
- ✅ Frontend will auto-rebuild and deploy
- ✅ No manual steps needed!

---

## Option 2: Manual Updates (If you prefer)

If you want to manually control when the website updates, use the provided script.

### Steps:

1. **Run the update script:**
   ```bash
   update-website.bat
   ```
   This will:
   - Build the Flutter web app
   - Copy files to the `frontend/` directory

2. **Commit and push:**
   ```bash
   git add frontend
   git commit -m "Update website with latest changes"
   git push
   ```

3. **Deploy to Render:**
   - If you have a separate static site on Render pointing to the `frontend/` directory, it will auto-deploy
   - Otherwise, you'll need to set one up manually

---

## Current Setup Analysis

### Mobile App (✅ Working)
- **Source:** `my_app/` directory
- **Build:** `flutter build apk` creates a fresh APK every time
- **Result:** Always has latest code

### Website (❌ Not Working)
- **Source:** `my_app/` directory
- **Current Deploy:** `frontend/` directory (contains OLD static files)
- **Problem:** The `frontend/` folder is not being updated when you make changes
- **Solution:** Use Option 1 (automatic) or Option 2 (manual script)

---

## Recommended Workflow

### For Development:
1. Make changes in `my_app/` directory
2. Test locally:
   - Mobile: `flutter run` on emulator/device
   - Web: `flutter run -d chrome`

### For Deployment:
1. Commit and push your changes to GitHub
2. Render automatically deploys both backend and frontend (if using Option 1)
3. Test the live website

---

## Troubleshooting

### Website still shows old content after deployment:
1. **Clear browser cache:** Hard refresh with Ctrl+F5
2. **Check Render logs:** Verify the build completed successfully
3. **Verify files:** Check that `my_app/build/web/` has the latest build

### Build fails on Render:
1. **Check build.sh:** Make sure it's executable
2. **Check Flutter version:** Render uses the stable channel
3. **View logs:** Check Render dashboard for specific errors

### API calls fail from website:
1. **Update CORS:** Add your frontend URL to backend CORS settings
2. **Check API URL:** Verify `my_app/assets/env/app.env` has correct production URL
3. **Rebuild:** After changing env files, rebuild the web app

---

## Files Modified

- ✅ `render.yaml` - Added frontend deployment configuration
- ✅ `update-website.bat` - Created manual update script

---

## Next Steps

**Choose your preferred option:**

### If using Option 1 (Automatic):
```bash
git add render.yaml
git commit -m "Add frontend auto-deployment"
git push
```
Then wait for Render to deploy both services.

### If using Option 2 (Manual):
```bash
update-website.bat
git add frontend
git commit -m "Update website"
git push
```

---

## Questions?

- **How often does Render deploy?** Every time you push to the `main` branch
- **Does this cost money?** No, both services can use Render's free tier
- **Can I use a custom domain?** Yes, configure it in Render dashboard
- **What about the mobile app?** Continue building APKs as usual - this doesn't affect it

---

Good luck! 🚀
