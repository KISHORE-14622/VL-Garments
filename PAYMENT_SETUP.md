# Payment System Setup Guide

This guide explains how to set up and use the payment system in VL-Garments admin panel.

## Features

### 1. Payments Tab
- Located above "Payment History" in the admin dashboard
- Shows all pending payments for workers
- Calculates pending amounts based on:
  - Total work done (production entries)
  - Already paid amounts
  - Work period dates

### 2. Payment Methods

#### A. Cash Payment
- Enter the amount paid manually
- Click the tick/confirm button to record the payment
- Payment is immediately marked as "paid" in the system

#### B. Razorpay Integration
- Online payment gateway integration
- Secure payment processing
- Automatic payment verification
- Payment details stored with transaction IDs

## Setup Instructions

### Backend Setup

1. **Install Razorpay Package**
   ```bash
   cd backend
   npm install razorpay
   ```

2. **Configure Razorpay Credentials**
   - Sign up at [Razorpay Dashboard](https://dashboard.razorpay.com/)
   - Navigate to Settings → API Keys
   - Copy your Key ID and Key Secret
   - Add to `backend/.env`:
     ```
     RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
     RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
     ```

3. **Restart Backend Server**
   ```bash
   npm run dev
   ```

### Frontend Setup

1. **Install Flutter Dependencies**
   ```bash
   cd my_app
   flutter pub get
   ```

2. **Configure Razorpay Key**
   - Add your Razorpay Key ID to `my_app/assets/env/app.env`:
     ```
     API_URL=http://localhost:3000/api
     RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
     ```

3. **Android Configuration** (if using Android)
   - Add to `android/app/src/main/AndroidManifest.xml` inside `<application>` tag:
     ```xml
     <activity
         android:name="com.razorpay.CheckoutActivity"
         android:configChanges="keyboard|keyboardHidden|orientation|screenSize"
         android:exported="true"
         android:theme="@style/CheckoutTheme">
         <intent-filter>
             <action android:name="android.intent.action.MAIN" />
         </intent-filter>
     </activity>
     ```

4. **iOS Configuration** (if using iOS)
   - No additional configuration needed

5. **Run the App**
   ```bash
   flutter run
   ```

## Usage Guide

### For Admin Users

1. **Navigate to Payments**
   - Open Admin Dashboard
   - Click on "Payments" card (orange icon with payment symbol)

2. **View Pending Payments**
   - See list of all staff with pending payments
   - Each card shows:
     - Staff name and phone number
     - Pending amount
     - Work period dates
     - Number of work days
     - Total earned vs already paid

3. **Process Payment via Razorpay**
   - Click "Pay via Razorpay" button
   - Razorpay checkout will open
   - Complete payment using:
     - Credit/Debit Card
     - Net Banking
     - UPI
     - Wallets
   - Payment is automatically verified and recorded

4. **Process Cash Payment**
   - Click "Cash Payment" button
   - Enter the amount paid in cash
   - Click "Confirm Payment"
   - Payment is recorded immediately

5. **View Payment History**
   - Navigate to "Payment History" tab
   - See all completed payments
   - Filter by status (All/Paid/Pending)

## Payment Calculation Logic

The system automatically calculates pending payments:

1. **Total Earned**: Sum of (quantity × rate) for all production entries
2. **Already Paid**: Sum of all "paid" payment records
3. **Pending Amount**: Total Earned - Already Paid
4. **Work Period**: Date range from first to last unpaid production entry

## API Endpoints

### Create Payment Order (Razorpay)
```
POST /api/payments/razorpay/create-order
Headers: Authorization: Bearer <token>
Body: {
  "amount": 1000.00,
  "currency": "INR"
}
Response: {
  "orderId": "order_xxxxx",
  "amount": 100000,
  "currency": "INR",
  "keyId": "rzp_test_xxxxx"
}
```

### Verify Payment (Razorpay)
```
POST /api/payments/razorpay/verify
Headers: Authorization: Bearer <token>
Body: {
  "razorpay_order_id": "order_xxxxx",
  "razorpay_payment_id": "pay_xxxxx",
  "razorpay_signature": "signature_xxxxx"
}
Response: {
  "verified": true
}
```

### Create Payment Record
```
POST /api/payments
Headers: Authorization: Bearer <token>
Body: {
  "staff": "staff_id",
  "amount": 1000.00,
  "periodStart": "2024-01-01T00:00:00.000Z",
  "periodEnd": "2024-01-31T23:59:59.999Z",
  "status": "paid",
  "paymentMethod": "razorpay",
  "razorpayPaymentId": "pay_xxxxx",
  "razorpayOrderId": "order_xxxxx"
}
```

## Testing

### Test Mode (Razorpay)
Use test credentials from Razorpay dashboard:
- Test cards: https://razorpay.com/docs/payments/payments/test-card-details/
- Example: Card Number: 4111 1111 1111 1111, CVV: Any 3 digits, Expiry: Any future date

### Production Mode
1. Complete KYC on Razorpay
2. Switch to live mode in Razorpay dashboard
3. Update `.env` files with live credentials
4. Test with small amounts first

## Security Notes

1. **Never commit** `.env` files with actual credentials
2. **Use environment variables** for all sensitive data
3. **Verify payments** on the server side (already implemented)
4. **Use HTTPS** in production
5. **Keep Razorpay SDK updated** for security patches

## Troubleshooting

### Payment Gateway Not Opening
- Check if Razorpay Key ID is correctly set in `app.env`
- Verify internet connection
- Check console for errors

### Payment Verification Failed
- Ensure Razorpay Key Secret is correct in backend `.env`
- Check if signature verification is working
- Review server logs

### Payment Not Recorded
- Check if backend API is running
- Verify authentication token is valid
- Check network requests in browser/app console

## Support

For Razorpay-specific issues:
- Documentation: https://razorpay.com/docs/
- Support: https://razorpay.com/support/

For app-specific issues:
- Check application logs
- Review API responses
- Verify database records
