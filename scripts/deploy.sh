#!/bin/bash
set -euo pipefail

# --------------------------------------------------
# Deploy script — pull latest code and restart services
# Run on the EC2 instance after pushing new code to GitHub
# Usage: bash scripts/deploy.sh
# --------------------------------------------------

APP_DIR="/home/ubuntu/django-hello-world"

echo "=== Pulling latest code ==="
cd "$APP_DIR"
git pull origin main

echo "=== Activating virtual environment ==="
source venv/bin/activate

echo "=== Installing dependencies ==="
pip install -r requirements.txt

echo "=== Running migrations (if any) ==="
python manage.py migrate --run-syncdb 2>/dev/null || true

echo "=== Collecting static files ==="
python manage.py collectstatic --noinput

echo "=== Restarting Gunicorn ==="
sudo systemctl daemon-reload
sudo systemctl restart gunicorn.socket
sudo systemctl restart gunicorn.service

echo "=== Reloading Nginx ==="
sudo nginx -t
sudo systemctl reload nginx

echo "=== Deployment complete! ==="
