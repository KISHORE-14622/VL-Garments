# Quick Start Guide - Payment System

## 🚀 Getting Started in 5 Minutes

### Step 1: Configure Razorpay (Optional for Cash Payments)

1. **Sign up at Razorpay** (if you want online payments)
   - Visit: https://dashboard.razorpay.com/signup
   - Complete registration

2. **Get API Keys**
   - Go to Settings → API Keys
   - Generate Test Keys (for testing) or Live Keys (for production)
   - Copy both Key ID and Key Secret

### Step 2: Configure Backend

1. **Update Backend Environment**
   ```bash
   # Navigate to backend folder
   cd backend
   
   # Edit .env file (create if doesn't exist)
   # Add these lines:
   RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
   RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
   ```

2. **Start Backend Server**
   ```bash
   npm run dev
   ```

### Step 3: Configure Frontend

1. **Update Flutter Environment**
   ```bash
   # Edit my_app/assets/env/app.env
   # Add this line:
   RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
   ```

2. **Run Flutter App**
   ```bash
   cd my_app
   flutter run
   ```

### Step 4: Use the Payment System

1. **Login as Admin**
   - Open the app
   - Login with admin credentials

2. **Navigate to Payments**
   - From Admin Dashboard
   - Click on "Payments" card (orange icon)

3. **Process Payments**
   
   **For Cash Payment:**
   - Click "Cash Payment" button
   - Enter amount paid
   - Click "Confirm Payment"
   - Done! ✅

   **For Razorpay Payment:**
   - Click "Pay via Razorpay" button
   - Razorpay checkout opens
   - Complete payment
   - Payment auto-verified ✅

## 📱 UI Flow

```
Admin Dashboard
    ↓
[Payments] Card (Click)
    ↓
Pending Payments Screen
    ↓
Staff List with Pending Amounts
    ↓
Choose Payment Method:
    ├─→ [Cash Payment] → Enter Amount → Confirm
    └─→ [Razorpay] → Checkout → Pay → Auto-verify
```

## 🎯 Key Features

### Automatic Calculation
- ✅ System calculates pending amounts automatically
- ✅ Based on production entries and previous payments
- ✅ Shows work period and days worked

### Two Payment Methods
- 💵 **Cash**: Manual entry with confirmation
- 💳 **Razorpay**: Online payment with auto-verification

### Payment Tracking
- 📊 View all pending payments in one place
- 📝 Complete payment history
- 🔍 Filter by status (Paid/Pending)

## 🧪 Testing with Razorpay

### Test Cards (Test Mode Only)
```
Card Number: 4111 1111 1111 1111
CVV: Any 3 digits (e.g., 123)
Expiry: Any future date (e.g., 12/25)
Name: Any name
```

### Test UPI
```
UPI ID: success@razorpay
```

### Expected Flow
1. Click "Pay via Razorpay"
2. Razorpay checkout opens
3. Select payment method
4. Use test credentials above
5. Payment succeeds
6. System verifies and records payment
7. Success message appears

## ⚠️ Important Notes

### For Cash Payments Only
- You can skip Razorpay configuration
- Just use the "Cash Payment" button
- Enter amount and confirm

### For Razorpay Payments
- Must configure API keys in both backend and frontend
- Test mode is free and safe for testing
- Switch to live mode only after KYC completion

### Security
- ✅ Never commit .env files to git
- ✅ Keep API secrets secure
- ✅ Use test mode for development
- ✅ All payments are verified server-side

## 🐛 Troubleshooting

### "Razorpay is not configured" Error
- Check if RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET are in backend .env
- Restart backend server after adding keys

### Payment Gateway Not Opening
- Verify RAZORPAY_KEY_ID is in my_app/assets/env/app.env
- Restart Flutter app after adding key
- Check internet connection

### Payment Not Recording
- Ensure backend server is running
- Check if you're logged in as admin
- Verify API_URL in app.env is correct

## 📞 Need Help?

### Razorpay Documentation
- https://razorpay.com/docs/

### Test Payment Details
- https://razorpay.com/docs/payments/payments/test-card-details/

### Support
- Check PAYMENT_SETUP.md for detailed guide
- Review PAYMENT_IMPLEMENTATION_SUMMARY.md for technical details

## ✅ Checklist

Before going live:
- [ ] Backend .env configured with Razorpay keys
- [ ] Frontend app.env configured with Razorpay key
- [ ] Backend server running
- [ ] Flutter app running
- [ ] Tested cash payment
- [ ] Tested Razorpay payment (if using)
- [ ] Verified payments appear in Payment History
- [ ] Completed Razorpay KYC (for production)
- [ ] Switched to live keys (for production)

---

**That's it! You're ready to process payments! 🎉**
