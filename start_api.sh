#!/bin/bash
# Titan OSINT — Start the FastAPI backend for mobile app

cd "$(dirname "$0")"

echo "⚡ Starting Titan OSINT API..."
echo "📱 Mobile app can connect to: http://$(hostname -I | awk '{print $1}'):8000"
echo ""

uvicorn api:app --host 0.0.0.0 --port 8000 --reload
