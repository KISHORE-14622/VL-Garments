# How to Run the Mobile App

## Why Run on Mobile?
- ✅ **Razorpay works** (not supported on web)
- ✅ **Full features** available
- ✅ **Better performance**
- ✅ **Native UI/UX**

---

## Option 1: Android Emulator (Easiest)

### Prerequisites
1. **Android Studio** - [Download here](https://developer.android.com/studio)
2. **Flutter SDK** - Already installed ✅
3. **Android SDK** - Comes with Android Studio

### Setup Android Emulator

#### Step 1: Install Android Studio
1. Download and install Android Studio
2. During installation, make sure to install:
   - Android SDK
   - Android SDK Platform
   - Android Virtual Device (AVD)

#### Step 2: Create Virtual Device
1. Open Android Studio
2. Click **"More Actions"** → **"Virtual Device Manager"**
3. Click **"Create Device"**
4. Choose a device (e.g., **Pixel 7**)
5. Select a system image (e.g., **Android 13 (API 33)**)
6. Click **"Finish"**

#### Step 3: Configure Flutter
```bash
# Check if Flutter can see the Android SDK
flutter doctor

# If Android toolchain shows issues, run:
flutter doctor --android-licenses
```

#### Step 4: Run the App
```bash
# Navigate to project
cd C:\Users\Admin\Desktop\projects\VL-Garments\my_app

# List available devices
flutter devices

# Run on Android emulator
flutter run
# Then select the Android device from the list
```

**Or run directly:**
```bash
flutter run -d android
```

---

## Option 2: Physical Android Device (Best Performance)

### Prerequisites
- Android phone with **USB debugging enabled**
- USB cable

### Steps

#### Step 1: Enable Developer Options on Phone
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. Go back to **Settings** → **Developer Options**
4. Enable **USB Debugging**

#### Step 2: Connect Phone
1. Connect phone to computer via USB
2. On phone, allow **USB debugging** when prompted
3. Select **File Transfer** mode

#### Step 3: Verify Connection
```bash
# Check if Flutter sees your device
flutter devices
```

You should see your phone listed.

#### Step 4: Run the App
```bash
cd C:\Users\Admin\Desktop\projects\VL-Garments\my_app
flutter run
# Select your physical device from the list
```

---

## Option 3: iOS Simulator (Mac Only)

### Prerequisites
- **macOS** computer
- **Xcode** installed
- **iOS Simulator**

### Steps
```bash
# Open iOS Simulator
open -a Simulator

# Run Flutter app
cd /path/to/VL-Garments/my_app
flutter run -d ios
```

---

## Option 4: Windows Desktop App

While Razorpay won't work on desktop, you can still test other features:

```bash
cd C:\Users\Admin\Desktop\projects\VL-Garments\my_app
flutter run -d windows
```

---

## Quick Command Reference

### Check Available Devices
```bash
flutter devices
```

### Run on Specific Device
```bash
# Android emulator
flutter run -d android

# Physical device (if only one connected)
flutter run

# Chrome (web)
flutter run -d chrome

# Windows desktop
flutter run -d windows
```

### Hot Reload (While App is Running)
- Press `r` in terminal for **hot reload**
- Press `R` for **hot restart**
- Press `q` to **quit**

---

## Troubleshooting

### "No devices found"
**Solution:**
```bash
# Check Flutter setup
flutter doctor -v

# For Android issues
flutter doctor --android-licenses
```

### "Android SDK not found"
**Solution:**
1. Install Android Studio
2. Open Android Studio → SDK Manager
3. Install Android SDK
4. Set environment variable:
   ```
   ANDROID_HOME=C:\Users\YourName\AppData\Local\Android\Sdk
   ```

### "Unable to locate adb"
**Solution:**
Add to PATH:
```
C:\Users\YourName\AppData\Local\Android\Sdk\platform-tools
```

### Emulator is Slow
**Solutions:**
1. Enable **Hardware Acceleration** (Intel HAXM or AMD Hypervisor)
2. Allocate more RAM to emulator (in AVD settings)
3. Use a physical device instead

---

## Testing Razorpay on Mobile

Once the app is running on Android/iOS:

1. **Navigate to Payments Screen**
2. **Click "Pay via Razorpay"** on any pending payment
3. **Razorpay checkout will open** (native UI)
4. **Test with Razorpay test cards:**
   - Card: `4111 1111 1111 1111`
   - CVV: Any 3 digits
   - Expiry: Any future date

---

## Building APK for Distribution

### Debug APK (for testing)
```bash
cd C:\Users\Admin\Desktop\projects\VL-Garments\my_app
flutter build apk --debug
```
APK location: `build/app/outputs/flutter-apk/app-debug.apk`

### Release APK (for production)
```bash
flutter build apk --release
```
APK location: `build/app/outputs/flutter-apk/app-release.apk`

### Install APK on Phone
1. Transfer APK to phone
2. Open APK file on phone
3. Allow installation from unknown sources
4. Install and run

---

## Current Setup Status

✅ **Backend**: Running at `https://vl-garments.onrender.com`
✅ **API URL**: Configured in `my_app/assets/env/app.env`
✅ **Razorpay**: Configured with test credentials
✅ **Mobile Support**: Ready to run on Android/iOS

---

## Next Steps

1. **Install Android Studio** (if not already installed)
2. **Create an Android Emulator**
3. **Run `flutter devices`** to verify setup
4. **Run `flutter run`** and select Android device
5. **Test Razorpay payments** on mobile

---

## Need Help?

Run this command to check your Flutter setup:
```bash
flutter doctor -v
```

This will show you what's missing and how to fix it.
