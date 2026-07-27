#!/bin/bash
# Production Server Update Script for Kallpa
# Server: 63.250.38.196 (actual IP from curl icanhazip.com)
# User: kallugwo
# Domain: kallpainmovilaria.com (pending DNS propagation)
# Run this script on the production server after SSH

set -e

echo "📦 KALLPA PRODUCTION UPDATE"
echo "===================================="
echo ""

cd /home/kallugwo/kallpa || exit 1

echo "✓ Navigated to /home/kallugwo/kallpa"
echo ""

# Step 1: Pull latest changes from GitHub
echo "📥 Pulling latest changes from GitHub..."
git pull origin main
echo "✓ Git pull completed"
echo ""

# Step 2: Install/upgrade dependencies
echo "📦 Installing Python dependencies..."
python3 -m pip install --user --upgrade -r requirements.txt
echo "✓ Dependencies installed"
echo ""

# Step 3: Specifically ensure reportlab works
echo "🔧 Ensuring reportlab and Pillow compatibility..."
python3 -m pip install --user reportlab==3.6.8 Pillow==9.0.0 --upgrade
echo "✓ reportlab and Pillow verified"
echo ""

# Step 4: Kill existing Flask processes
echo "🛑 Stopping existing Flask instances..."
pkill -9 -f "python3 main.py" 2>/dev/null || true
sleep 2
echo "✓ Flask processes stopped"
echo ""

# Step 5: Clean Python cache
echo "🧹 Cleaning Python cache..."
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
rm -rf ./__pycache__ 2>/dev/null || true
echo "✓ Cache cleaned"
echo ""

# Step 6: Start Flask in background
echo "🚀 Starting Flask application..."
nohup python3 main.py > app.log 2>&1 &
sleep 3
echo "✓ Flask started"
echo ""

# Step 7: Verify Flask is running
echo "🔍 Verifying Flask is responding..."
if curl -s http://localhost:5000/welcome | grep -q "Gestiona tus"; then
    echo "✓ Flask is responding correctly with Kallpa interface"
else
    echo "⚠️  Flask responded but content may differ"
fi
echo ""

# Step 8: Check logs for errors
echo "📋 Checking application logs (last 20 lines):"
tail -20 app.log
echo ""

echo "===================================="
echo "✓ UPDATE COMPLETED SUCCESSFULLY"
echo ""
echo "📌 Next Steps:"
echo "1. Verify DNS propagation: nslookup kallpainmovilaria.com"
echo "2. Check PHP proxy at: /home/kallugwo/public_html/index.php"
echo "3. Test via browser: https://kallpainmovilaria.com"
echo "4. Monitor logs: tail -f app.log"
echo ""
