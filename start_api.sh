#!/bin/bash
# Titan OSINT — Start the FastAPI backend for mobile app
#
# Optional env vars:
#   TITAN_API_KEY  — if set, all API calls must include header: X-API-Key: <value>
#   CORS_ORIGINS   — comma-separated allowed origins (default: * for local dev)
#   HOST           — bind address (default: 0.0.0.0 for LAN access)
#   PORT           — port number (default: 8000)

cd "$(dirname "$0")"

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

echo "⚡ Starting Titan OSINT API on ${HOST}:${PORT}"
if [ -n "$TITAN_API_KEY" ]; then
    echo "🔒 Auth enabled — set X-API-Key header in the app Settings screen"
fi
echo "📱 Mobile app URL: http://${LOCAL_IP:-localhost}:${PORT}"
echo ""

uvicorn api:app --host "$HOST" --port "$PORT"
