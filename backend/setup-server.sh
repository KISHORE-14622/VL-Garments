#!/bin/bash
# =============================================
# VL-Garments — Oracle Cloud VM First-Time Setup
# Run this ONCE on a fresh Ubuntu VM
# Usage: bash setup-server.sh
# =============================================

set -e

echo "🔧 VL-Garments Server Setup Starting..."
echo "============================================"

# 1. Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Install Node.js 20 LTS
echo "📦 Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "  Node.js version: $(node --version)"
echo "  npm version: $(npm --version)"

# 3. Install PM2 globally
echo "📦 Installing PM2..."
sudo npm install -g pm2

# 4. Install Nginx
echo "📦 Installing Nginx..."
sudo apt install -y nginx

# 5. Install Certbot for SSL (optional, needs domain)
echo "📦 Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx

# 6. Install Git
echo "📦 Installing Git..."
sudo apt install -y git

# 7. Open firewall ports
echo "🔥 Configuring firewall..."
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 5000 -j ACCEPT

# Save iptables rules
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

# 8. Clone the repository
echo "📥 Cloning VL-Garments repository..."
cd ~
git clone https://github.com/KISHORE-14622/VL-Garments.git
cd VL-Garments/backend

# 9. Install dependencies
echo "📦 Installing Node.js dependencies..."
npm install --production

# 10. Create .env file
echo "📝 Creating .env file..."
echo "⚠️  You need to edit this file with your actual secrets!"
cat > .env << 'EOF'
PORT=5000
MONGODB_URI=mongodb+srv://Viji:YOUR_PASSWORD@vl-garments.hrspio9.mongodb.net/?appName=VL-Garments
JWT_SECRET=YOUR_JWT_SECRET
RAZORPAY_KEY_SECRET=YOUR_RAZORPAY_SECRET
RAZORPAY_KEY_ID=YOUR_RAZORPAY_KEY
NODE_ENV=production
EOF

echo ""
echo "⚠️  IMPORTANT: Edit the .env file with your real secrets:"
echo "   nano ~/VL-Garments/backend/.env"
echo ""

# 11. Create logs directory
mkdir -p logs

# 12. Make deploy script executable
chmod +x deploy.sh

# 13. Configure Nginx
echo "🌐 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/vl-garments > /dev/null << 'NGINX'
server {
    listen 80;
    server_name _;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX

# Enable the site
sudo ln -sf /etc/nginx/sites-available/vl-garments /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "============================================"
echo "✅ Server Setup Complete!"
echo "============================================"
echo ""
echo "📋 Next steps:"
echo "  1. Edit your .env file:"
echo "     nano ~/VL-Garments/backend/.env"
echo ""
echo "  2. Start the server:"
echo "     cd ~/VL-Garments/backend"
echo "     pm2 start ecosystem.config.cjs"
echo "     pm2 startup"
echo "     pm2 save"
echo ""
echo "  3. Test it:"
echo "     curl http://localhost:5000/health"
echo ""
echo "  4. Your API is accessible at:"
echo "     http://YOUR_VM_PUBLIC_IP/health"
echo ""
echo "  5. For future deploys, just run:"
echo "     cd ~/VL-Garments/backend && ./deploy.sh"
echo ""
