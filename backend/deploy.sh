#!/bin/bash
# =============================================
# VL-Garments Backend — One-Command Deploy Script
# Run this on your Oracle Cloud VM to deploy updates
# Usage: ./deploy.sh
# =============================================

set -e

echo "🚀 VL-Garments Backend Deploy Starting..."
echo "============================================"

# Navigate to project directory
cd ~/VL-Garments/backend

# Pull latest code
echo "📥 Pulling latest code from GitHub..."
git pull origin master

# Install dependencies (only if package.json changed)
echo "📦 Installing dependencies..."
npm install --production

# Restart the server using PM2
echo "🔄 Restarting server..."
pm2 restart vl-garments || pm2 start ecosystem.config.cjs

# Save PM2 process list
pm2 save

# Show status
echo ""
echo "============================================"
echo "✅ Deploy Complete!"
echo "============================================"
pm2 status
echo ""
echo "📋 Recent logs:"
pm2 logs vl-garments --lines 5 --nostream
